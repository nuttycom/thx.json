import utest.Runner;
import utest.ui.Report;
import utest.Assert;

import thx.json.*;
import thx.json.schema.*;

class TestAll {
  public static function main() {
    var runner = new Runner();
    runner.addCase(new TestRender());
    runner.addCase(new TestJValue());
    runner.addCase(new TestSchemaExtensions());
    Report.create(runner);
    runner.run();
  }
}
