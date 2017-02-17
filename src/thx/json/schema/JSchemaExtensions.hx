package thx.json.schema;

import haxe.ds.Option;

import thx.Options;
import thx.Monoid;
import thx.Nel;
import thx.ReadonlyArray;
import thx.Validation;
import thx.Validation.*;
import thx.Tuple;
import thx.Unit;
import thx.json.Render;
import thx.json.JValue;
import thx.json.JValue.*;
import thx.json.schema.SchemaExtensions;
import thx.fp.Functions.*;
import thx.fp.Writer;
using thx.Arrays;
using thx.Eithers;
using thx.Functions;
using thx.Iterators;
using thx.Maps;
using thx.Options;
using thx.ReadonlyArray;
using thx.Validation.ValidationExtensions;

import thx.schema.SchemaF;
using thx.schema.SchemaFExtensions;
using thx.schema.SchemaGenExtensions;

import thx.json.schema.JSchema;
import thx.json.schema.JSchema.SchemaDSL.*;
using thx.json.schema.JSMeta;

typedef JSPropSchema<E, O, A> = PropSchema<E, JSMeta, O, A>;

class JSchemaExtensions {
  public static function jsonSchema<E, A>(schema: JSchema<E, A>): JValue {
    function baseSchema(type: String, m: CommonMetadata): Array<JAssoc> {
      var opts: Map<String, JValue> = if (m.opts == null) new Map() else m.opts;
      if (m.hidden != null) opts["hidden"] = jBool(m.hidden);

      return [
        { name: "type",  value: JString(type) },
        { name: "title", value: JString(m.title) },
        if (m.id != null) { name: "id", value: JString(m.id) } else null,
        if (m.format != null) { name: "format", value: JString(m.format) } else null,
        if (m.description != null) { name: "description", value: JString(m.description) } else null,
        if (opts.keys().hasNext()) { name: "options", value: jObject(opts) } else null
      ].filterNull();
    }

    var m: CommonMetadata = schema.annotation.commonMetadata();
    return switch schema.schema {
      case IntSchema:   JObject(baseSchema("integer", m));
      case FloatSchema: JObject(baseSchema("number", m));
      case BoolSchema:  JObject(baseSchema("boolean", m));

      case StrSchema:   
        var strMetaAttrs = schema.annotation.strMetadata().toArray().flatMap(
          function(strm: StrMetadata) return [
            if (strm.minLength != null) { name: "minLength", value: JNum(strm.minLength) } else null,
            if (strm.maxLength != null) { name: "maxLength", value: JNum(strm.maxLength) } else null,
            if (strm.pattern != null)   { name: "pattern",   value: JString(strm.pattern) } else null
          ].filterNull()
        );

        JObject(baseSchema("string", m).concat(strMetaAttrs));

      case AnySchema:   
        JObject(baseSchema("object", m));

      case ConstSchema(_):
        jObject([
          "type" => jString("object"), 
          "additionalProperties" => jBool(false),
          "options" => jObject([ "hidden" => jBool(true) ])
        ]);

      case ObjectSchema(propSchema):
        JObject(
          baseSchema("object", m).concat([
            { name: "properties", value: JObject(objectProperties(propSchema)) },
            { name: "required", value: jArray(requiredProperties(propSchema).map(JString)) }
          ])
        );

      case ArraySchema(elemSchema):
        var arrMetaAttrs = schema.annotation.arrayMetadata().toArray().flatMap(
          function(a: ArrayMetadata) return [
            { name: "items", value: jsonSchema(elemSchema) },
            if (a.minItems != null) { name: "minItems", value: jNum(a.minItems) } else null,
            if (a.maxItems != null) { name: "maxItems", value: jNum(a.maxItems) } else null,
            if (a.uniqueItems != null) { name: "uniqueItems", value: jBool(a.uniqueItems) } else null
          ].filterNull()
        );

        JObject(baseSchema("array", m).concat(arrMetaAttrs));

      case MapSchema(valueSchema):
        throw new thx.Error("JSON-Schema generation for dictionary-structured data not yet implemented.");

      case OneOfSchema(alternatives):
        var singularAlternatives = alternatives.traverseOption(
          function(alt) return switch alt {
            case Prism(_, base, m, _, _): base.constMeta().map(const(Tuple.of(m.commonMetadata(), alt)));
          }
        );

        JObject(
          switch singularAlternatives {
            case Some(alts):
              // generate an enum schema
              baseSchema("string", m).concat([
                { name: "enum", value: JArray(alts.map(function(alt) return JString(alt._1.id()))) },
                {
                  name: "options",
                  value: JObject([
                    { name: "enum_titles", value: JArray(alts.map(function(alt) return JString(alt._0.title))) }
                  ])
                }
              ]);
            case None:
              // generate a schema for sums-of-products
              baseSchema("object", m).concat([
                { name: "oneOf", value: JArray(alternatives.map(alternativeSchema)) }
              ]);
          }
        );

      case ParseSchema(base, _, _):
        jsonSchema(new AnnotatedSchema(schema.annotation, base));

      case LazySchema(delay):
        jsonSchema(new AnnotatedSchema(schema.annotation, delay()));
    };
  }

  private static function useEnumStyle<E, A>(alternatives: Array<Alternative<E, JSMeta, A>>): Bool {
    return alternatives.all(
      function(alt) return switch alt {
        case Prism(_, base, _, _): base.constMeta().toBool();
      }
    );
  }

  private static function alternativeSchema<E, A>(alt: Alternative<E, JSMeta, A>): JValue {
    function baseSchema(m: CommonMetadata, valueProperties: Array<JAssoc>): Array<JAssoc>
      return [
        { name: "type",  value: JString("object") },
        { name: "title", value: JString(m.title) },
        { name: "properties", value: JObject(valueProperties) },
        { name: "required", value: JArray([ JString(alt.id()) ]) },
        { name: "additionalProperties", value: JBool(false) },
        if (m.id != null) { name: "id", value: JString(m.id) } else null
      ].filterNull();

    return switch alt {
      case Prism(id, s, m, _, _): JObject(baseSchema(m.commonMetadata(), [{ name: alt.id(), value: jsonSchema(s) }]));
    }
  }

  public static function objectProperties<E, O, X>(builder: JSPropsBuilder<E, O, X>): Array<JAssoc> {
    function go<E, O, I, J>(schema: JSPropSchema<E, O, I>, k: JSPropsBuilder<E, O, I -> J>): Array<JAssoc> {
      var schemaAssoc: Array<JAssoc> = switch schema {
        case Required(field, valueSchema, _, _):
          [{ name: field, value: jsonSchema(valueSchema) }];

        case Optional(field, valueSchema, _):
          [{ name: field, value: jsonSchema(valueSchema) }];
      };

      return schemaAssoc.concat(objectProperties(k));
    }

    return switch builder {
      case Pure(a): [];
      case Ap(s, k): go(s, k);
    };
  }

  public static function requiredProperties<E, O, X>(builder: JSPropsBuilder<E, O, X>): Array<String> {
    function go<E, O, I, J>(schema: JSPropSchema<E, O, I>, k: JSPropsBuilder<E, O, I -> J>): Array<String> {
      var required = switch schema {
        case Required(field, valueSchema, _, None): [field];
        case _: [];
      };

      return required.concat(requiredProperties(k));
    }

    return switch builder {
      case Pure(a): [];
      case Ap(s, k): go(s, k);
    };
  }

  public static function withTitle<E, A>(s: JSchema<E, A>, title: String): JSchema<E, A> {
    function modify(v: ValMetadata) return switch v {
      case CommonM(m): 
        CommonM({
          title: title,
          id: m.id,
          format: m.format,
          description: m.description,
          hidden: m.hidden,
          opts: m.opts
        });
      case StrM(m): 
        StrM({
          title: title,
          id: m.id,
          format: m.format,
          description: m.description,
          hidden: m.hidden,
          opts: m.opts,
          minLength: m.minLength,
          maxLength: m.maxLength,
          pattern: m.pattern
        });
      case ArrayM(m):
        ArrayM({
          title: title,
          id: m.id,
          format: m.format,
          description: m.description,
          hidden: m.hidden,
          opts: m.opts,
          minItems: m.minItems,
          maxItems: m.maxItems,
          uniqueItems: m.uniqueItems,
        });
    }

    return s.mapAnnotation(
      function(s: JSMeta): JSMeta return switch s {
        case Value(v): Value(modify(v));
        case Alt(v): Alt(Value(modify(CommonM(v))).commonMetadata()); //nasty hack
        case Prop(p, v): Prop(p, modify(v));
      }
    );
  }
}
