package thx.json.schema;

import utest.Assert;
import haxe.ds.Option;

import thx.Validation.*;
import thx.json.*;
import thx.json.JValue;

import thx.schema.SchemaDSL.*;
using thx.schema.SchemaGenExtensions;
using thx.json.schema.SchemaExtensions;
using thx.json.schema.JSchemaExtensions;

import thx.json.schema.JSchema;
import thx.json.schema.JSchema.SchemaDSL.*;


using StringTools;

@:sequence(s, b)
typedef O = { s: String, b: Option<Bool> };

@:sequence(i, o)
typedef T = { i: Int, o: O }

enum TestEnum {
  TestA;
  TestB;
}

enum TestADT {
  TestI(i: Int);
  TestS(s: String, ao: Array<O>);
  TestX;
}

class TestJSchema {
  static var intSchema: JSchema<String, Int> = int({ title: "Test" });

  static var oSchema: JSchema<String, O> = object(
    { title: "TestO", id: "testo" },
    ap2(
      thx.Make.constructor(O),
      required("s", {}, str({ title: "S", minLength: 1 }), function(o: O) return o.s),
      optional("b", {}, bool({ title: "B" }), function(o: O) return o.b)
    )
  );

  static var aSchema: JSchema<String, Array<O>> = array({ title: "ArrayOfO" }, oSchema);

  static var tSchema: JSchema<String, T> = object(
    { title: "TestT", id: "testt" },
    ap2(
      thx.Make.constructor(T),
      required("i", {}, int({ title: "I" }), function(t: T) return t.i),
      required("o", {}, oSchema, function(t: T) return t.o)
    )
  );

  static var eSchema: JSchema<String, TestEnum> = oneOf(
    { title: "TestEnum", id: "testenum" },
    [
      constEnum("testA", { title: "TestA" }, TestA),
      constEnum("testB", { title: "TestB" }, TestB)
    ]
  );

  static var sumSchema: JSchema<String, TestADT> = oneOf(
    { title: "TestADT", id: "testadt" },
    [
      alt(
        "testI",
        int({ title: "TestI" }), 
        TestI, 
        function(a: TestADT) return switch a {
          case TestI(i): Some(i);
          case _: None;
        }
      ),
      alt(
        "testS",
        object(
          { title: "TestS" }, 
          ap2( 
            function(s, ao) return { s: s, ao: ao },
            required("s", {}, str({ title: "S" }), function(x: {s: String, ao: Array<O> }) return x.s), 
            required("ao", {}, aSchema, function(x: {s: String, ao: Array<O> }) return x.ao)
          )
        ),
        function(x: {s: String, ao: Array<O> }) return TestS(x.s, x.ao),
        function(a: TestADT) return switch a {
          case TestS(s, ao): Some({ s: s, ao: ao });
          case _: None;
        }
      ),
      constEnum("testX", { title: "TestX"}, TestX)
    ]
  );

  static var testS: JValue = JObject([ 
    { name: "testS", value: JObject([
      { name: "s", value: JString("hello") },
      { name: "ao", value: JArray(
          [ JObject([{ name: "s", value: JString("beautiful") }, { name: "b", value: JBool(false) }])
          , JObject([{ name: "s", value: JString("world") }])
          ]) } 
    ]) }
  ]);

  public function new() { }

  public function testParsePrimitive() {
    Assert.same(successNel(1), intSchema.parseJSON(JNum(1.0)));
  }

  public function testParseObject() {
    var testValue = JObject([ 
      { name: "i", value: JNum(1.0) },
      { name: "o", value: JObject([{ name: "s", value: JString("sv") }, { name: "b", value: JBool(false) }]) }
    ]);

    Assert.same(successNel({ i: 1, o: { s: "sv", b: Some(false) } }), tSchema.parseJSON(testValue));
  }

  public function testJsonSchema() {
    var expected = JObject([
      { name: "type", value: JString("object") },
      { name: "title", value: JString("TestT") },
      { name: "id", value: JString("testt") },
      {  
        name: "properties", 
        value: JObject([
          {
            name: "i", 
            value: JObject([
              { name: "type",  value: JString("integer") },
              { name: "title", value: JString("I") },
            ]) 
          },
          { 
            name: "o",
            value: JObject([
              { name: "type", value: JString("object") },
              { name: "title", value: JString("TestO") },
              { name: "id", value: JString("testo") },
              {
                name: "properties",
                value: JObject([
                  { 
                    name: "s",
                    value: JObject([
                      { name: "type", value: JString("string") },
                      { name: "title", value: JString("S") },
                      { name: "minLength", value: JNum(1) },
                    ])
                  },
                  {
                    name: "b",
                    value: JObject([
                      { name: "type", value: JString("boolean") },
                      { name: "title", value: JString("B") }
                    ])
                  }
                ])
              },
              { 
                name: "required",
                value: JArray([JString("s")])
              }
            ])
          }
        ])
      },
      { 
        name: "required",
        value: JArray([JString("i"), JString("o")])
      }
    ]);

    Assert.same(expected, tSchema.jsonSchema());
  }

  public function testEnumSchema() {
    var expected = JObject([
      { name: "type",  value: JString("string") },
      { name: "title", value: JString("TestEnum") },
      { name: "id",    value: JString("testenum") },
      { name: "enum",  value: JArray(["testA","testB"].map(JString)) },
      { 
        name: "options",
        value: JObject([
          { 
            name: "enum_titles", 
            value: JArray(["TestA","TestB"].map(JString)) 
          }
        ])
      }
    ]);

    Assert.same(expected, eSchema.jsonSchema());
  }

  public function testParseEnum() {
    Assert.same(successNel(TestA), eSchema.parseJSON(JString("testA")));
    Assert.same(successNel(TestB), eSchema.parseJSON(JString("testB")));
  }

  public function testParseSum() {
    var testX = JObject([ { name: "testX", value: JNull } ]);
    Assert.same(successNel(TestX), sumSchema.parseJSON(testX));

    var testI = JObject([ 
      { name: "testI", value: JNum(1.0) }
    ]);
    Assert.same(successNel(TestI(1)), sumSchema.parseJSON(testI));

    var result = sumSchema.parseJSON(testS);
    Assert.same(successNel(TestS("hello", [{ s: "beautiful", b: Some(false) }, { s: "world", b: None }])), result);
  }

  public function testOneOfSchema() {
    var expected = '{
      "type":"object",
      "title":"TestADT",
      "id":"testadt",
      "oneOf":[
        {
          "type":"object",
          "title":"TestI",
          "properties": {
            "testI":{
              "type":"integer",
              "title":"TestI"
            }
          },
          "required":["testI"],
          "additionalProperties":false
        },
        {
          "type":"object",
          "title":"TestS",
          "properties":{
            "testS":{
              "type":"object",
              "title":"TestS",
              "properties":{
                "s":{
                  "type":"string","title":"S"
                },
                "ao":{
                  "type":"array",
                  "title":"ArrayOfO",
                  "items":{
                    "type":"object",
                    "title":"TestO",
                    "id":"testo",
                    "properties":{
                      "s":{"type":"string","title":"S","minLength":1},
                      "b":{"type":"boolean","title":"B"}
                    },
                    "required": ["s"]
                  }
                }
              },
              "required": ["s", "ao"]
            }
          },
          "required":["testS"],
          "additionalProperties":false
        },
        {
          "type":"object",
          "title":"TestX",
          "properties":{
            "testX":{
              "type":"object",
              "additionalProperties":false,
              "options": { "hidden": true }
            }
          },
          "required":["testX"],
          "additionalProperties":false
        }
      ]
    }';

    Assert.same(expected.replace(" ", "").replace("\n", ""), Render.renderUnsafe(sumSchema.jsonSchema()));
  }
}
