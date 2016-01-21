package thx.json;

import haxe.ds.Option;
import utest.Assert;
import thx.json.JValue.*;
import thx.json.JValue.JSearch;

class TestJValue {
  public function new() { }

  public function testPathSyntax() {
    var obj = jObject([
      "a" => jNum(1), 
      "b" => jNum(2), 
      "c" => jArray([jNum(3), jNum(4)]),
      "n" => jNull
    ]);

    Assert.same(Some(jNum(4)), (obj / "c")[1]);
  }
}


