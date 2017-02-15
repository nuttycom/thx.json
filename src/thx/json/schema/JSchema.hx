package thx.json.schema;

import haxe.ds.Option;

import thx.Either;
import thx.Functions.identity;
import thx.LocalDate;
import thx.Options;
import thx.Monoid;
import thx.Nel;
import thx.Nothing;
import thx.Validation;
import thx.Validation.*;
import thx.Unit;
import thx.fp.Functions.*;
import thx.fp.Writer;
using thx.Bools;

import thx.schema.SchemaF;
import thx.schema.SchemaDSL.*;
using thx.schema.SchemaFExtensions;

import thx.json.JValue;
using thx.json.schema.SchemaExtensions;
using thx.json.schema.JSMeta;

using thx.Arrays;
using thx.Eithers;
using thx.Functions;
using thx.Iterators;
using thx.Maps;
using thx.Options;

typedef JSchema<E, A> = AnnotatedSchema<E, JSMeta, A>;

typedef JSPropsBuilder<E, O, A> = PropsBuilder<E, JSMeta, O, A>;
typedef JSObjectBuilder<E, A> = ObjectBuilder<E, JSMeta, A>;

class SchemaDSL {
  private static function liftMS<E, A>(m: CommonMetadata, s: SchemaF<E, JSMeta, A>): JSchema<E, A>
    return new AnnotatedSchema(Value(CommonM(m)), s);

  //
  // Constructors for terminal schema elements
  //

  public static function bool<E> (m: CommonMetadata): JSchema<E, Bool>
    return liftMS(m, BoolSchema);

  public static function int<E> (m: CommonMetadata): JSchema<E, Int>
    return liftMS(m, IntSchema);

  public static function num<E> (m: CommonMetadata): JSchema<E, Float>
    return liftMS(m, FloatSchema);

  public static function str<E> (m: StrMetadata): JSchema<E, String>
    return new AnnotatedSchema(Value(StrM(m)), StrSchema);

  public static function constS<E, A>(m: CommonMetadata, a: A): JSchema<E, A>
    return liftMS(m, ConstSchema(a));

  public static function array<E, A>(m: ArrayMetadata, elemSchema: JSchema<E, A>): JSchema<E, Array<A>>
    return new AnnotatedSchema((Value(ArrayM(m))), ArraySchema(elemSchema));

  public static function object<E, A>(m: CommonMetadata, propSchema: ObjectBuilder<E, JSMeta, A>): JSchema<E, A>
    return liftMS(m, ObjectSchema(propSchema));

  public static function oneOf<E, A>(m: CommonMetadata, alternatives: Array<Alternative<E, JSMeta, A>>): JSchema<E, A>
    return liftMS(m, OneOfSchema(alternatives));

  //
  // Constructors for oneOf alternatives
  //

  public static function constAlt<E, B>(id: String, m: CommonMetadata, b: B, equal: B -> B -> Bool): Alternative<E, JSMeta, B>
    return Prism(id, constS(m, b), identity, function(b0) return equal(b, b0).option(b));

  public static function constAltEq<E, B>(id: String, m: CommonMetadata, b: B): Alternative<E, JSMeta, B>
    return constAlt(id, m, b, thx.Dynamics.equals);

  public static function constEnum<E, B : EnumValue>(id: String, m: CommonMetadata, b: B): Alternative<E, JSMeta, B>
    return constAlt(id, m, b, Type.enumEq);

  //
  // Constructors for object properties. TODO: Create some intermediate typedefs to make
  // a fluent interface for this construction.
  //

  public static function required<E, O, A>(fieldName: String, m: PropMetadata, valueSchema: JSchema<E, A>, accessor: O -> A, ?dflt: Option<A>): JSPropsBuilder<E, O, A> {
    var annSchema = new AnnotatedSchema(Prop(m, valueSchema.valMetadata()), valueSchema.schema);
    return Ap(Required(fieldName, annSchema, accessor, if (dflt == null) None else dflt), Pure(identity));
  }

  public static function optional<E, O, A>(fieldName: String, m: PropMetadata, valueSchema: JSchema<E, A>, accessor: O -> Option<A>): JSPropsBuilder<E, O, Option<A>> {
    var annSchema = new AnnotatedSchema(Prop(m, valueSchema.valMetadata()), valueSchema.schema);
    return Ap(Optional(fieldName, annSchema, accessor), Pure(identity));
  }

  public static function property<E, O, A>(fieldName: String, m: PropMetadata, valueSchema: JSchema<E, A>, accessor: O -> A, dflt: A): JSPropsBuilder<E, O, A> {
    var annSchema = new AnnotatedSchema(Prop(m, valueSchema.valMetadata()), valueSchema.schema);
    return Ap(Required(fieldName, annSchema, accessor, Some(dflt)), Pure(identity));
  }

  // Convenience constructor for a single-property object schema that simply wraps another schema.
  public static function wrap<E, A>(fieldName: String, valueSchema: JSchema<E, A>, ?m: CommonMetadata): JSchema<E, A> {
    return object(
      if (m == null) valueSchema.commonMetadata() else m, 
      required(fieldName, {}, valueSchema, function(a: A) return a)
    );
  }
}
