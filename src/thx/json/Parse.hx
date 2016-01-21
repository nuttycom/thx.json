package thx.json;

import haxe.ds.Option;
import thx.Validation;
import thx.Validation.*;
using thx.Functions;
using thx.Arrays;
using thx.Options;

import thx.json.JValue;
import thx.json.schema.JType;

class Parse {
  public static function parseProperty<A>(v: JValue, name: String, f: JValue -> VNel<String, A>): VNel<String, A>
    return switch v {
      case JObject(assocs): 
        assocs.findOption.fn(_.name == name).map.fn(_.value).toSuccessNel('Object does not contain the key "$name"').flatMapV(f);

      case other: 
        failureNel('Value of type ${JType.forValue(other).name()} is not a JSON object.');
    };
}
