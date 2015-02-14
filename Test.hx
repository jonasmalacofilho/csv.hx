import utest.Assert;
import utest.Runner;
import utest.ui.Report;

@:access(Parser)
class BaseTest {
    var eol:String;

    function parser(text)
    {
        return new Parser(text, ",", "\"", eol);
    }

    function parseRecord(text)
    {
        return "[" + parser(text).record().join("|") + "]";
    }

    function parseCsv(text)
    {
        return "{" + Parser.parse(text, ",", "\"", eol)
            .map(function (x) return "["+x.join("|")+"]").join(";") + "}";
    }

    public function testParseRecord()
    {
        Assert.same('[a|b|c]', parseRecord('a,b,c'));
        // escaping
        Assert.same('[a|b|c]', parseRecord('"a",b,c'));
        Assert.same('["a"|b|c]', parseRecord('"""a""",b,c'));
        Assert.same('[a"a|b|c]', parseRecord('"a""a",b,c'));  // esc
        Assert.same('[a,a|b|c]', parseRecord('"a,a",b,c'));  // sep
        Assert.same('[a${eol}a|b|c]', parseRecord('"a${eol}a",b,c'));  // eol
        Assert.same('[a",${eol}"a|b|c]', parseRecord('"a"",${eol}""a",b,c'));  // esc, sep & eol
        // empty fields
        Assert.same('[||]', parseRecord(',,'));
        Assert.same('[||]', parseRecord('"","",""'));
    }

    public function testParseCsv()
    {
        // multiple records
        Assert.same('{[a|b|c];[d|e|f]}', parseCsv('a,b,c${eol}d,e,f'));
        // empty string
        Assert.same('{[]}', parseCsv(''));
        // single record with/without eol
        Assert.same('{[a|b|c]}', parseCsv('a,b,c'));
        Assert.same('{[a|b|c]}', parseCsv('a,b,c${eol}'));
    }
}

class TestNixEol extends BaseTest {
    public function new()
    {
        this.eol = "\n";
    }
}

class TestWindowsEol extends BaseTest {
    public function new()
    {
        this.eol = "\r\n";
    }
}

class Test {
    static function main()
    {
        var r = new Runner();
        r.addCase(new TestNixEol());
        r.addCase(new TestWindowsEol());
        Report.create(r);
        r.run();
    }
}

