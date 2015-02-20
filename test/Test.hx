import format.csv.rdp.*;
import utest.*;
import utest.ui.Report;

class BaseTest {
    var eol:String;

    public function testNormalRecordReading()
    {
        var reader = new Parser(",", "\"", eol);
        function r(str)
        {
            reader.reset(str, null);
            return reader.readRecord();
        }

        Assert.same(["a","b","c"], r('a,b,c'));
        // escaping
        Assert.same(["a","b","c"], r('"a",b,c'));
        Assert.same(['"a"',"b","c"], r('"""a""",b,c'));
        Assert.same(['a"a',"b","c"], r('"a""a",b,c'));  // esc
        Assert.same(['a,a',"b","c"], r('"a,a",b,c'));  // sep
        Assert.same(['a${eol}a',"b","c"], r('"a${eol}a",b,c'));  // eol
        Assert.same(['a",${eol}"a',"b","c"], r('"a"",${eol}""a",b,c'));  // esc, sep & eol
        // empty fields
        Assert.same(["","",""], r(',,'));
        Assert.same(["","",""], r('"","",""'));
    }

    public function testSafeUtf8RecordReading()
    {
        function r(reader, str)
        {
            reader.reset(str, null);
            return reader.readRecord();
        }

        var n = new Parser(",", "\"", eol);
        var u = new Utf8Parser(",", "\"", eol);

        Assert.same(["α","β","γ"], r(n, 'α,β,γ'));
        Assert.same(["α","β","γ"], r(u, 'α,β,γ'));
    }

    public function testUnsafeUtf8RecordReading()
    {
        function r(reader, str)
        {
            reader.reset(str, null);
            return reader.readRecord();
        }

#if (js || java || cs || swf)
        // on targets where String already has unicode support, the Utf8Parser
        // shouldn't be necessary
        var n = new Parser("➔", "✍", eol);
        Assert.same(["a","b","c"], r(n, 'a➔b➔c'));
        Assert.same(["a","b","c"], r(n, '✍a✍➔b➔c'));
        Assert.same(["α","β","γ"], r(n, 'α➔β➔γ'));
#end
        var u = new Utf8Parser("➔", "✍", eol);
        Assert.same(["a","b","c"], r(u, 'a➔b➔c'));
        Assert.same(["a","b","c"], r(u, '✍a✍➔b➔c'));
        Assert.same(["α","β","γ"], r(u, 'α➔β➔γ'));
    }

    public function testNormalReadAll()
    {
        var reader = new Parser(",", "\"", eol);
        function r(str)
        {
            reader.reset(str, null);
            return reader.readAll();
        }

        // multiple records
        Assert.same([["a","b","c"], ["d","e","f"]], r('a,b,c${eol}d,e,f'));
        // empty string
        Assert.equals([[]].toString(), r('').toString());  // FIXME bug on utest
        // single record with/without eol
        Assert.same([["a","b","c"]], r('a,b,c'));
        Assert.same([["a","b","c"]], r('a,b,c${eol}'));
    }

    public function testUtf8ReadAll()
    {
        var reader = new Utf8Parser(",", "\"", eol);
        function r(str)
        {
            reader.reset(str, null);
            return reader.readAll();
        }

        // multiple records
        Assert.same([["a","b","c"], ["d","e","f"]], r('a,b,c${eol}d,e,f'));
        // empty string
        Assert.equals([[]].toString(), r('').toString());  // FIXME bug on utest
        // single record with/without eol
        Assert.same([["a","b","c"]], r('a,b,c'));
        Assert.same([["a","b","c"]], r('a,b,c${eol}'));
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

