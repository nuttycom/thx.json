import utest.Runner;
import utest.ui.Report;
import utest.Assert;

import thx.json.*;

class TestAll {
  public static function main() {
    var runner = new Runner();
    runner.addCase(new TestRender());
    runner.addCase(new TestJValue());
    Report.create(runner);
    runner.run();
  }
}
