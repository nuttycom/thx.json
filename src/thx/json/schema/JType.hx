package thx.json.schema;

import thx.json.JValue;

enum JTypeADT {
  JArrayT;
  JBoolT;
  JIntT;
  JNumT;
  JNullT;
  JObjT;
  JStringT;
}

abstract JType (JTypeADT) from JTypeADT to JTypeADT {
  public static function forValue(v: JValue): JType
    return switch v {
      case JString(_): JStringT;
      case JNum(_): JNumT;
      case JBool(_): JBoolT;
      case JArray(_): JArrayT;
      case JObject(_): JObjT;
      case JNull: JNullT;
    };

  public function name(): String
    return switch this {
      case JArrayT:  "array";
      case JBoolT:   "boolean";
      case JIntT:    "integer";
      case JNumT:    "number";
      case JNullT:   "null";
      case JObjT:    "object";
      case JStringT: "string";
    };
}

