package thx.json.schema;

import haxe.ds.Option;

import thx.schema.SchemaF;
import thx.json.JValue;

typedef CommonMetadata = {
  title: String,
  ?id: String,
  ?format: String,
  ?hidden: Bool,
  ?opts: Map<String, JValue>
};

typedef ArrayMetadata = { > CommonMetadata,
  ?minItems: Int,
  ?maxItems: Int,
  ?uniqueItems: Bool
};

typedef PropMetadata = { 
  ?propIdx: Int, 
  ?opts: Map<String, JValue>
};

enum ValMetadata {
  CommonM(m: CommonMetadata);
  ArrayM(m: ArrayMetadata);
}

enum JSMeta {
  Value(valMeta: ValMetadata);
  Prop(propMeta: PropMetadata, valMeta: ValMetadata);
}



/**
 * A couple of useful interpreters for Schema values. This class is intended
 * to be imported via 'using'.
 */
class JSMetaExtensions {
  public static function valMetadata<E, A>(s: AnnotatedSchema<E, JSMeta, A>): ValMetadata
    return switch s.annotation {
      case Value(valMeta): valMeta;
      case Prop(_, valMeta): valMeta;
    };

  public static function commonMetadata<E, A>(s: AnnotatedSchema<E, JSMeta, A>): CommonMetadata
    return switch valMetadata(s) {
      case CommonM(c): c;
      case ArrayM(a): a;
    };

  public static function arrayMetadata<E, A>(s: AnnotatedSchema<E, JSMeta, A>): ArrayMetadata
    return switch valMetadata(s) {
      case CommonM(c): c;
      case ArrayM(a): a;
    };

  public static function constMeta<E, A>(schema: AnnotatedSchema<E, JSMeta, A>): Option<CommonMetadata> {
    return _constMeta(commonMetadata(schema), schema.schema);
  };

  static function _constMeta<E, A>(m: CommonMetadata, s: SchemaF<E, JSMeta, A>): Option<CommonMetadata> {
    return switch s {
      case ConstSchema(_): Some(m);
      case ParseSchema(s0, _, _): _constMeta(m, s0);
      case LazySchema(fs): _constMeta(m, fs());
      case _: None;
    };
  }
}
