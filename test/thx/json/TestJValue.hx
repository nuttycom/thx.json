package thx.json;

import haxe.ds.Option;
import thx.Either;

import utest.Assert;

import thx.json.JValue;
import thx.json.JValue.*;
import thx.json.JValue.JPath.*;
import thx.json.JValue.JSearch;
import thx.json.schema.JType;



class TestJValue {
  static var ox = jObject([ "x" => jNum(3) ]);
  static var arr = jArray([ox, jNum(4)]);
  static var obj = jObject([
    "a" => jNum(1), 
    "b" => jNum(2), 
    "c" => arr,
    "n" => jNull
  ]);

  public function new() { }

  public function testPathSyntax() {
    Assert.same(Right(jNum(4)), (obj/"c"*1).run());
  }

  public function testPathGet() {
    var path = root/"c"*0/"x";

    Assert.same(Right(jNum(3)), obj.get(path));
  }

  public function testArrayError() {
    Assert.same(Left({ path: Index(2, Property("c", Empty)), error: IndexOutOfRange(2, arr) }), (obj/"c"*2).run());
    Assert.same(Left({ path: Index(2, Property("n", Empty)), error: TypeMismatch(JArrayT, jNull) }), (obj/"n"*2).run());
    Assert.same(Left({ path: Index(2, Property("c", Empty)), error: IndexOutOfRange(2, arr) }), (obj/"c"*2/"x").run());
  }

  public function testPropertyError() {
    Assert.same(Left({ path: Property("y", Index(0, Property("c", Empty))), error: NoSuchProperty("y", ox) }), (obj/"c"*0/"y").run());
  }
}
