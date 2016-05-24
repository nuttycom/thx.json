package thx.json.schema;

import haxe.ds.Option;
import haxe.Json;
import thx.Either;

import utest.Assert;

import thx.json.JValue;
import thx.json.JValue.*;
import thx.json.JValue.JPath.*;
import thx.json.JValue.JSearch;
using thx.json.schema.SchemaExtensions;

import thx.schema.Schema;
import thx.schema.SchemaDSL.*;
using thx.schema.SchemaExtensions;


class TSimple {
  public var x: Int;

  public function new(x: Int) {
    this.x = x;
  }

  public static var schema(default, never): Schema<TSimple> = object(required("x", int, function(ts: TSimple) return ts.x).map(TSimple.new));
}

enum TEnum {
  EX(o: TSimple);
  EY(s: String);
  EZ;
}

class TEnums {
  public static var schema: Schema<TEnum> = oneOf([
    alt("ex", TSimple.schema, function(s) return EX(s), function(e: TEnum) return switch e { case EX(s): Some(s); case _: None; }),
    alt("ey", string,       function(s) return EY(s), function(e: TEnum) return switch e { case EY(s): Some(s); case _: None; }),
    alt("ez", constant(EZ), function(s) return EZ   , function(e: TEnum) return switch e { case EZ:    Some(null); case _: None; })
  ]);
}

class TComplex {
  public var i: Int;
  public var f: Float;
  public var b: Bool;
  public var a: Array<TSimple>;
  public var e: Option<TEnum>;

  public function new(i: Int, f: Float, b: Bool, a: Array<TSimple>, e: Option<TEnum>) {
    this.i = i; 
    this.f = f;
    this.b = b;
    this.a = a;
    this.e = e;
  }

  public static var schema(default, never): Schema<TComplex> = object(
    ap5(
      TComplex.new,
      required("i", int, function(tc: TComplex) return tc.i), 
      required("f", float, function(tc: TComplex) return tc.f), 
      required("b", bool, function(tc: TComplex) return tc.b), 
      required("a", array(TSimple.schema), function(tc: TComplex) return tc.a), 
      optional("e", TEnums.schema, function(tc: TComplex) return tc.e)
    )
  );
}

class TestSchemaExtensions {
  public function new() { }

  public function testRender() {
    var rendered = TComplex.schema.renderJSON(new TComplex(1, 2, true, [new TSimple(3), new TSimple(4)], Some(EX(new TSimple(5)))));
    var path = JPath.root / "a" * 1 / "x";
    Assert.same(Right(JNum(4.0)), rendered.get(path));
  }
}

