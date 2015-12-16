package thx.json;

typedef JAssoc = {
  name: String,
  value: JValue
};

enum JValue {
  JString(s: String);
  JNum(x: Float);
  JBool(b: Bool);
  JArray(xs: Array<JValue>);
  JObject(xs: Array<JAssoc>);
  JNull;
}


