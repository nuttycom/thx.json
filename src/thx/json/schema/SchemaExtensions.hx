package thx.json.schema;

import haxe.ds.Option;

import thx.Unit;
import thx.Validation;
import thx.Validation.*;
import thx.fp.Writer;
using thx.Arrays;
using thx.Functions;
using thx.Options;

import thx.Validation;
import thx.schema.Schema;
import thx.schema.Schema.Schema;
import thx.schema.SchemaDSL.*;
using thx.schema.SchemaExtensions;

import thx.json.JValue;
import thx.json.JValue.*;

class SchemaExtensions {
  inline static public function fail<A>(message: String, path: JPath): VNel<ParseError, A>
    return failureNel(new ParseError(message, path));

  public static function parseJSON<A>(schema: Schema<A>, v: JValue): VNel<ParseError, A> {
    return parseJSON0(schema, v, JPath.root);
  }

  private static function parseJSON0<A>(schema: Schema<A>, v: JValue, path: JPath): VNel<ParseError, A> {
    // helper function used to unpack existential type I
    return switch schema {
      case IntSchema:
        switch v {
          case JNum(n): 
            if (Math.round(n) == n) successNel(Math.round(n)) 
            else fail('$n is not an integer value.', path);
          case other: 
            fail('Value ${Render.renderUnsafe(v)} is not a JSON numeric value.', path);
        };

      case FloatSchema:
        switch v {
          case JNum(n): successNel(n);
          case other: fail('Value ${Render.renderUnsafe(v)} is not a JSON numeric value.', path);
        }

      case StrSchema:
        switch v {
          case JString(s): successNel(s);
          case other: fail('Value ${Render.renderUnsafe(v)} is not a JSON string value.', path);
        };

      case BoolSchema:
        switch v {
          case JBool(b): successNel(b);
          case other: fail('Value ${Render.renderUnsafe(v)} is not a JSON boolean value.', path);
        };

      case UnitSchema: 
        switch v {
          case JNull: successNel(unit);
          case other: fail('Value ${Render.renderUnsafe(v)} is not JSON null.', path);
        };

      case ObjectSchema(propSchema):
        parseObject(propSchema, v, path);

      case ArraySchema(elemSchema): 
        switch v {
          case JArray(values): values.traverseValidationIndexed(function(v, i) return parseJSON0(elemSchema, v, path * i), Nel.semigroup());
          case other: fail('Value ${Render.renderUnsafe(v)} is not a JSON array.', path);
        };

      case OneOfSchema(alternatives):
        //if (useEnumStyle(alternatives)) {
        //  // TODO: Handle non-string enumerations of constant values.
        //  switch v {
        //    case JString(s):
        //      switch alternatives.findOption.fn(_.id() == s) {
        //        case Some(Prism(id, base, f, _)):
        //          parseJSON0(base, v, path / id).map(f);

        //        case None:
        //          fail('Value ${Render.renderUnsafe(v)} cannot be mapped to any known value of the enum.', path);
        //      };
        //    case other: 
        //      fail('Value ${Render.renderUnsafe(v)} is not a JSON string.', path);
        //  }
        //} else {
          switch v {
            case JObject(assocs): 
              // This is specific to the encoding which demands that exactly one of the map's keys is 
              // represented among the alternatives
              switch assocs.flatMap(function(a) return alternatives.filter.fn(_.id() == a.name)) {
                case [Prism(id, base, f, _)]:
                  parseAlternative(id, base, v, path / id).map(f);

                case other:
                  if (other.length == 0) {
                    fail('Could not match type identifier from among ${alternatives.map.fn(_.id())} among keys ${assocs.map.fn(_.name)}', path);
                  } else {
                    fail('Ambiguous JSON value ${Render.renderUnsafe(v)}: all of ${other.map.fn(_.id())} are valid type identifiers.', path);
                  }
              }

            case other: 
              fail('Value ${Render.renderUnsafe(v)} is not a JSON object.', path);
          }
        //}

      case IsoSchema(base, f, _): 
        parseJSON0(base, v, path).map(f);

      case LazySchema(base):
        parseJSON0(base(), v, path);
    };
  }

  /**
   * This helper function is the companion to alternativeSchema; both
   * are private helpers for the parse and jsonSchema functions, respectively
   */ 
  private static function parseAlternative<A>(id: String, schema: Schema<A>, value: JValue, path: JPath): VNel<ParseError, A> {
    function parseAltPrimitive<X>(schema: Schema<X>, assocs: Array<JAssoc>): VNel<ParseError, X> {
      return switch assocs.findOption.fn(_.name == id) {
        case Some(v): parseJSON0(schema, v.value, path / id);
        case None: fail('Object ${Render.renderUnsafe(value)} does not contain required property "value"', path);
      };
    }

    return switch value {
      case JObject(assocs):
        switch schema {
          case UnitSchema: successNel(null);
          case ObjectSchema(propSchema): parseObject(propSchema, value, path);
          case IsoSchema(base, f, _): parseAlternative(id, base, value, path).map(f);
          case LazySchema(base): parseAlternative(id, base(), value, path);
          case other: parseAltPrimitive(other, assocs); 
        };

      case other:
        fail('Value ${Render.renderUnsafe(value)} is not a JSON object.', path);
    };
  }

  private static function parseObject<O, A>(builder: ObjectBuilder<O, A>, v: JValue, path: JPath): VNel<ParseError, A> {
    // helper function used to unpack existential type I
    inline function go<I>(schema: PropSchema<O, I>, k: ObjectBuilder<O, I -> A>): VNel<ParseError, A> {
      var parsed: VNel<ParseError, I> = switch v {
        case JObject(assocs):
          switch schema {
            case Required(fieldName, valueSchema, _):
              switch assocs.findOption(function(a) return a.name == fieldName) {
                case Some(assoc):
                  parseJSON0(valueSchema, assoc.value, path / fieldName);

                case None: 
                  fail('Value ${Render.renderUnsafe(v)} does not contain key ${fieldName} and no default was available.', path);
              };

            case Optional(fieldName, valueSchema, _):
              var assoc: Option<JAssoc> = assocs.findOption(function(a) return a.name == fieldName);
              assoc.traverseValidation(function(a: JAssoc) return parseJSON0(valueSchema, a.value, path / fieldName));
          };

        case other: 
          fail('Value ${Render.renderUnsafe(v)} is not a JSON object.', path);
      };

      return parsed.ap(parseObject(k, v, path), Nel.semigroup());
    }

    return switch builder {
      case Pure(a): successNel(a);
      case Ap(s, k): go(s, k);
    };
  }

  // private static function useEnumStyle<A>(alternatives: Array<Alternative<A>>): Bool {
  //   return alternatives.all(
  //     function(alt) return switch alt {
  //       case Prism(_, base, _, _): base.nullMeta().toBool();
  //     }
  //   );
  // }

  public static function renderJSON<A>(schema: Schema<A>, value: A): JValue {
    return switch schema {
      case BoolSchema:  jBool(value);
      case FloatSchema: jNum(value);
      case IntSchema:   jNum(value * 1.0);
      case StrSchema:   jString(value);
      case UnitSchema:  jNull;

      case ObjectSchema(propSchema): renderObject(propSchema, value);
                          
      case ArraySchema(elemSchema): jArray(value.map(renderJSON.bind(elemSchema, _)));

      case OneOfSchema(alternatives): 
        var selected: Array<JValue> = alternatives.flatMap(
          function(alt) return switch alt {
            case Prism(id, base, _, g): 
              g(value).map(
                function(b) {
                  //return if (useEnumStyle(alternatives)) {
                  //  JString(id); 
                  //} else {
                    return switch renderJSON(base, b) {
                      case JObject(assocs): JObject([{ name: id, value: JNull }].concat(assocs));
                      case other: JObject([{ name: id, value: other }]); 
                    };
                  //}
                }
              ).toArray();
          }
        );

        switch selected {
          case []: 
            throw new thx.Error('None of ${alternatives.map.fn(_.id())} could convert the value $value to the base type ${thx.schema.SchemaExtensions.stype(schema)}');

          case other: 
            other.head();
            //'Ambiguous value $value: multiple alternatives for ${schema.metadata().title} (all of ${other.map(Render.renderUnsafe)}) claim to be valid renderings.';
        }

      case IsoSchema(base, _, g): 
        renderJSON(base, g(value));

      case LazySchema(base):
        renderJSON(base(), value);
    }
  }

  public static function renderObject<A>(builder: ObjectBuilder<A, A>, value: A): JValue {
    return JObject(evalRO(builder, value).runLog());
  }

  // should be inside renderObject, but haxe doesn't let you write corecursive
  // functions as inner functions
  private static function evalRO<O, X>(builder: ObjectBuilder<O, X>, value: O): Writer<Array<JAssoc>, X>
    return switch builder {
      case Pure(a): Writer.pure(a, wm);
      case Ap(s, k): goRO(s, k, value);
    };

  // should be inside renderObject, but haxe doesn't let you write corecursive
  // functions as inner functions
  private static function goRO<O, I, J>(schema: PropSchema<O, I>, k: ObjectBuilder<O, I -> J>, value: O): Writer<Array<JAssoc>, J> {
    var action: Writer<Array<JAssoc>, I> = switch schema {
      case Required(field, valueSchema, accessor):
        var i0 = accessor(value);
        Writer.tell([{ name: field, value: renderJSON(valueSchema, i0) }], wm) >> 
        Writer.pure(i0, wm);

      case Optional(field, valueSchema, accessor):
        var i0 = accessor(value);
        Writer.tell(i0.map(function(v0) return { name: field, value: renderJSON(valueSchema, v0) }).toArray(), wm) >> 
        Writer.pure(i0, wm);
    }

    return action.ap(evalRO(k, value));
  }

  // This value will be reused a bunch, so no need to re-create it all the time.
  private static var wm(default, never): Monoid<Array<JAssoc>> = Arrays.monoid();
}

class ParseError {
  public var message(default, null): String;
  public var path(default, null): JPath;

  public function new(message: String, path: JPath) {
    this.message = message;
    this.path = path;
  }

  public function toString(): String {
    return '${path.toString()}: ${message}';
  }
}
