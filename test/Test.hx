import format.csv.rdp.*;
import utest.*;
import utest.ui.Report;

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

    static function stringParser(text, sep, esc, eol, ?utf8=false)
    {
        var p = utf8 ? new Utf8Parser(sep, esc, eol) : new Parser(sep, esc, eol);
        p.reset(text);
        return p;
    }

    function parseRecord(text)
    {
        var p = stringParser(text, ",", "\"", eol);
        return recordString(p.readRecord());
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
        function parseUtf8(text)
        {
            var p = stringParser(text, ",", "\"", eol, true);
            return recordString(p.readRecord());
        }
        Assert.equals('[α|β|γ]', parseUtf8('α,β,γ'));
        
        Assert.equals('[α|β|γ]', parseRecord('α,β,γ'));
    }

    public function testAnyUtf8chars()
    {
        function parseUtf8(text)
        {
            var p = stringParser(text, "➔", "✍", eol, true);
            return recordString(p.readRecord());
        }

        Assert.equals('[a|b|c]', parseUtf8('a➔b➔c'));
        Assert.equals('[a|b|c]', parseUtf8('✍a✍➔b➔c'));
        Assert.equals('[α|β|γ]', parseUtf8('α➔β➔γ'));
    }

#if (js || java || cs || swf)
    // on targets where String already has unicode support, the Utf8Parser
    // shouldn't be necessary
    public function testNativeUnicodeSupport()
    {
        function parseUnicode(text)
        {
            var p = stringParser(text, "➔", "✍", eol, false);
            return recordString(p.readRecord());
        }
        Assert.equals('[a|b|c]', parseUnicode('a➔b➔c'));
        Assert.equals('[a|b|c]', parseUnicode('✍a✍➔b➔c'));
        Assert.equals('[α|β|γ]', parseUnicode('α➔β➔γ'));
    }
#end
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
        
#if sys
        var res:TestResult = null;
        r.onProgress.add(function (o) if (o.done == o.totals) res = o.result);
        r.run();
        Sys.exit(res.allOk() ? 0 : 1);
#else
        r.run();
#end
    }
}

