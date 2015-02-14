import utest.Assert;
import utest.Runner;
import utest.ui.Report;

@:access(Parser)
class Test {
    function new() {}

    function parseRecord(s)
    {
        var p = new Parser(s, ",", "\"");
        return p.record().join("|");
    }

    function testParseRecord()
    {
        Assert.same('a|b|c', parseRecord('a,b,c'));
        // escaping
        Assert.same('a|b|c', parseRecord('"a",b,c'));
        Assert.same('"a"|b|c', parseRecord('"""a""",b,c'));
        Assert.same('a,a|b|c', parseRecord('"a,a",b,c'));
        Assert.same('a","a|b|c', parseRecord('"a"",""a",b,c'));
        // empty fields
        Assert.same('||', parseRecord(',,'));
        Assert.same('||', parseRecord('"","",""'));
    }

    static function main()
    {
        var r = new Runner();
        r.addCase(new Test());
        Report.create(r);
        r.run();
    }
}

