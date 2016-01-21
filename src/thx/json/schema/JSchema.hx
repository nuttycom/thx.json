package thx.json.schema;

import thx.Url;
import thx.Either;
import thx.Nel;

typedef Schema = {
  @optional id: Url,
  @optional schema: Url,
  @optional title: String,
  @optional description: String,
  @optional default: JValue,

  @optional dependencies: Map<String, Either<JSchema, Array<String>>>,

  @optional enum: Array<JValue>,
  @optional type: Array<JType>,

  @optional allOf: Array<JSchema>,
  @optional anyOf: Array<JSchema>,
  @optional oneOf: Array<JSchema>,
  @optional not: Option<JSchema>,

  @optional definitions: Map<String, JSchema>
}

/**
 * Schema for boolean/null. This does not add any properties
 * beyond the base Schema class, but is simply present to refine
 * the type for use in the JSchemaADT type.
 */
typedef PrimSchema = {> Schema,
}

typedef NumSchema = {> Schema,
  @optional multipleOf: Option<Int>, //should be int > 0

  @optional minimum: Option<Float>,
  @optional exclusiveMinimum: Bool,

  @optional maximum: Option<Float>,
  @optional exclusiveMaximum: Bool
}

typedef StrSchema {> Schema,
  @optional minLength: Int, // should be int >= 0 
  @optional maxLength: Option<Int>, // should be int >= 0
  @optional pattern: Option<String>, // regex pattern
}

typedef ArraySchema {> Schema,
  @optional items: Nel<JSchema>>,
  @optional maxItems: Int, // should be int >= 0
  @optional minItems: Int, // should be int >= 0 
  @optional uniqueItems: Bool,
  @optional additionalItems: Either<JSchema, Bool>
}

typedef ObjectSchema {> Schema,
  @optional maxProperties: Int, // should be int >= 0
  @optional minProperties: Int, // should be int >= 0 
  @optional required: Array<String>,
  @optional properties: Map<String, JSchema>,
  @optional patternProperties: Map<String, JSchema>,
  @optional additionalProperties: Either<JSchema, Bool>
}
