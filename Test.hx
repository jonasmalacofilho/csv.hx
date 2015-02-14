import utest.Assert;
import utest.Runner;
import utest.ui.Report;

@:access(Parser)
class BaseTest {
    var eol:String;

    function recordString(rec:Array<String>)
    {
        return "[" + rec.join("|") + "]";
    }

    function csvString(csv:Array<Array<String>>)
    {
        return "{" + csv.map(recordString).join(";") + "}";
    }

    function parseRecord(text)
    {
        var p = new Parser(text, ",", "\"", eol);
        return recordString(p.record());
    }

    function parseCsv(text)
    {
        return csvString(Parser.parse(text, ",", "\"", eol));
    }

    public function testParseRecord()
    {
        Assert.equals('[a|b|c]', parseRecord('a,b,c'));
        // escaping
        Assert.equals('[a|b|c]', parseRecord('"a",b,c'));
        Assert.equals('["a"|b|c]', parseRecord('"""a""",b,c'));
        Assert.equals('[a"a|b|c]', parseRecord('"a""a",b,c'));  // esc
        Assert.equals('[a,a|b|c]', parseRecord('"a,a",b,c'));  // sep
        Assert.equals('[a${eol}a|b|c]', parseRecord('"a${eol}a",b,c'));  // eol
        Assert.equals('[a",${eol}"a|b|c]', parseRecord('"a"",${eol}""a",b,c'));  // esc, sep & eol
        // empty fields
        Assert.equals('[||]', parseRecord(',,'));
        Assert.equals('[||]', parseRecord('"","",""'));
    }

    public function testParseCsv()
    {
        // multiple records
        Assert.equals('{[a|b|c];[d|e|f]}', parseCsv('a,b,c${eol}d,e,f'));
        // empty string
        Assert.equals('{[]}', parseCsv(''));
        // single record with/without eol
        Assert.equals('{[a|b|c]}', parseCsv('a,b,c'));
        Assert.equals('{[a|b|c]}', parseCsv('a,b,c${eol}'));
    }

    public function testSafeUtf8chars()
    {
        Assert.equals('[α|β|γ]', parseRecord('α,β,γ'));  // should still work

        function parseUtf8(text)
        {
            var p = new Utf8Parser(text, ",", "\"", eol);
            return recordString(p.record());
        }
        Assert.equals('[α|β|γ]', parseUtf8('α,β,γ'));
    }

    public function testAnyUtf8chars()
    {
        function parseUtf8(text)
        {
            var p = new Utf8Parser(text, "➔", "✍", eol);
            return recordString(p.record());
        }

        Assert.equals('[a|b|c]', parseUtf8('a➔b➔c'));
        Assert.equals('[a|b|c]', parseUtf8('✍a✍➔b➔c'));
        Assert.equals('[α|β|γ]', parseUtf8('α➔β➔γ'));
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

