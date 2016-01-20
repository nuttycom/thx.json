package thx.json;

import utest.Assert;
import haxe.ds.Option;
import thx.json.JValue;
import thx.json.Render.*;

class TestRender {
  public function new() { }

  public function testRenderString() {
    Assert.same(None, render(JString("hello")));
    Assert.same("\"btnfr\"",   renderUnsafe(JString("btnfr")));
    //Assert.same("\"\\btnfr\"", renderUnsafe(JString("\btnfr")));
    Assert.same("\"b\\tnfr\"", renderUnsafe(JString("b\tnfr")));
    Assert.same("\"bt\\nfr\"", renderUnsafe(JString("bt\nfr")));
    //Assert.same("\"btn\\fr\"", renderUnsafe(JString("btn\fr")));
    Assert.same("\"btnf\\r\"", renderUnsafe(JString("btnf\r")));
    Assert.same("\"\\\\\"",      renderUnsafe(JString("\\")));
  }

  public function testRenderNumber() {
    Assert.same(None, render(JNum(1.0)));
    Assert.same("1",  renderUnsafe(JNum(1.0)));
    Assert.same("-1",  renderUnsafe(JNum(-1.0)));
  }

  public function testRenderBool() {
    Assert.same(None,    render(JBool(true)));
    Assert.same("true",  renderUnsafe(JBool(true)));
    Assert.same("false", renderUnsafe(JBool(false)));
  }

  public function testRenderArray() {
    Assert.same(Some("[1,2,3]"), render(JArray([JNum(1), JNum(2), JNum(3)])));
  }

  public function testRenderObject() {
    Assert.same(
      Some('{"a":1,"b":2,"c":[3,4]}'), 
      render(
        JObject([
          {name:"a", value:JNum(1)}, 
          {name:"b", value:JNum(2)}, 
          {name:"c", value:JArray([JNum(3), JNum(4)])}
        ])
      )
    );
  }

  public function testRenderNull() {
    Assert.same(None, render(JNull));
    Assert.same("null", renderUnsafe(JNull));
  }
}

