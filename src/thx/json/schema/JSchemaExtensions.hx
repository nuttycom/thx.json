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
        if (opts.keys().hasNext()) { name: "options", value: jObject(opts) } else null
      ].filterNull();
    }

    var m: CommonMetadata = schema.commonMetadata();
    return switch schema.schema {
      case IntSchema:   JObject(baseSchema("integer", m));
      case FloatSchema: JObject(baseSchema("number", m));
      case BoolSchema:  JObject(baseSchema("boolean", m));
      case StrSchema:   JObject(baseSchema("string", m));
      case AnySchema:   JObject(baseSchema("object", m));

      case ConstSchema(_):
        JObject(baseSchema("object", m));

      case ObjectSchema(propSchema):
        JObject(baseSchema("object", m).append({ name: "properties", value: JObject(objectProperties(propSchema)) }));

      case ArraySchema(elemSchema):
        var a = schema.arrayMetadata();
        JObject(
          baseSchema("array", m)
          .concat([{ name: "items", value: jsonSchema(elemSchema) }])
          .concat(if (a.minItems != null) [{ name: "minItems", value: jNum(a.minItems) }] else [])
          .concat(if (a.maxItems != null) [{ name: "maxItems", value: jNum(a.maxItems) }] else [])
          .concat(if (a.uniqueItems != null) [{ name: "uniqueItems", value: jBool(a.uniqueItems) }] else [])
        );

      case MapSchema(valueSchema):
        throw new thx.Error("JSON-Schema generation for dictionary-structured data not yet implemented.");

      case OneOfSchema(alternatives):
        var singularAlternatives = alternatives.traverseOption(
          function(alt) return switch alt {
            case Prism(_, base, _, _): base.constMeta().map(Tuple.of.bind(_, alt));
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
    function baseSchema(m: { title: String, ?id: String }, valueProperties: Array<JAssoc>): Array<JAssoc>
      return [
        { name: "type",  value: JString("object") },
        { name: "title", value: JString(m.title) },
        { name: "properties", value: JObject(valueProperties) },
        { name: "required", value: JArray([ JString(alt.id()) ]) },
        { name: "additionalProperties", value: JBool(false) },
        if (m.id != null) { name: "id", value: JString(m.id) } else null
      ].filterNull();

    return switch alt {
      case Prism(id, s, _, _):
        switch s.schema {
          // If the value schema is an object with no properties, wipe
          // out the title in the value schema.
          // FIXME: these first two cases are workarounds for the lack of metadata
          // in the Alternative constructor.
          case ConstSchema(_):
            var vSchema = jObject([
              "type" => jString("object"), 
              "additionalProperties" => jBool(false),
              "options" => jObject([ "hidden" => jBool(true) ])
            ]);
            JObject(baseSchema(s.commonMetadata(), [{ name: alt.id(), value: vSchema }]));

          case _:
            JObject(baseSchema(s.commonMetadata(), [{ name: alt.id(), value: jsonSchema(s) }]));
        }
    }
  }

  public static function objectProperties<E, O, X>(builder: JSPropsBuilder<E, O, X>): Array<JAssoc> {
    return evalBuilder(builder);
  }

  // should be inside objectProperties, but haxe doesn't let you write corecursive
  // functions as inner functions
  private static function evalBuilder<E, O, X>(builder: JSPropsBuilder<E, O, X>): Array<JAssoc>
    return switch builder {
      case Pure(a): [];
      case Ap(s, k): goOP(s, k);
    };

  // should be inside objectProperties, but haxe doesn't let you write corecursive
  // functions as inner functions
  // TODO: the fact that this requires the call to exemplar is an interesting design smell.
  // Not so stinky as to stop progress, but funky.
  private static function goOP<E, O, I, J>(schema: JSPropSchema<E, O, I>, k: JSPropsBuilder<E, O, I -> J>): Array<JAssoc> {
    var schemaAssoc: Array<JAssoc> = switch schema {
      case Required(field, valueSchema, _, _):
        [{ name: field, value: jsonSchema(valueSchema) }];

      case Optional(field, valueSchema, _):
        [{ name: field, value: jsonSchema(valueSchema) }];
    };

    return schemaAssoc.concat(evalBuilder(k));
  }

  public static function withTitle<E, A>(s: JSchema<E, A>, title: String): JSchema<E, A> {
    function modify(v: ValMetadata) return switch v {
      case CommonM(m): 
        CommonM({
          title: title,
          id: m.id,
          format: m.format,
          hidden: m.hidden,
          opts: m.opts
        });
      case ArrayM(m):
        ArrayM({
          title: title,
          id: m.id,
          format: m.format,
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
        case Prop(p, v): Prop(p, modify(v));
      }
    );
  }
}
