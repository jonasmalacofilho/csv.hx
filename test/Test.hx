import format.csv.*;
import haxe.crypto.BaseCode;
import haxe.io.*;
import utest.*;
import utest.ui.Report;

class BaseTest {
    var eol:String;

    public function test01_NormalRecordReading()
    {
        var reader = new Reader(",", "\"", eol);
        function r(str)
        {
            return reader.reset(str, null).next();
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

    public function test02_SafeUtf8RecordReading()
    {
        function r(reader, str)
        {
            return reader.reset(str, null).next();
        }

        var n = new Reader(",", "\"", eol);
        var u = new Utf8Reader(",", "\"", eol);

        Assert.same(["α","β","γ"], r(n, 'α,β,γ'));
        Assert.same(["α","β","γ"], r(u, 'α,β,γ'));
    }

    public function test03_UnsafeUtf8RecordReading()
    {
        function r(reader, str)
        {
            return reader.reset(str, null).next();
        }

#if (js || java || cs || swf)
        // on targets where String already has unicode support, the Utf8Reader
        // shouldn't be necessary
        var n = new Reader("➔", "✍", eol);
        Assert.same(["a","b","c"], r(n, 'a➔b➔c'));
        Assert.same(["a","b","c"], r(n, '✍a✍➔b➔c'));
        Assert.same(["α","β","γ"], r(n, 'α➔β➔γ'));
#end
        var u = new Utf8Reader("➔", "✍", eol);
        Assert.same(["a","b","c"], r(u, 'a➔b➔c'));
        Assert.same(["a","b","c"], r(u, '✍a✍➔b➔c'));
        Assert.same(["α","β","γ"], r(u, 'α➔β➔γ'));
    }

    public function test04_Read()
    {
        var n = Reader.read.bind(_, ",", "\"", eol);
        var u = Utf8Reader.read.bind(_, ",", "\"", eol);

        // string/normal reader
        // multiple records
        Assert.same([["a","b","c"], ["d","e","f"]], n('a,b,c${eol}d,e,f'));
        // empty string
        Assert.same([[""]].toString(), n('').toString());
        // single record with/without eol
        Assert.same([["a","b","c"]], n('a,b,c'));
        Assert.same([["a","b","c"]], n('a,b,c${eol}'));

        // utf8 reader
        // multiple records
        Assert.same([["a","b","c"], ["d","e","f"]], u('a,b,c${eol}d,e,f'));
        // empty string
        Assert.equals([[]].toString(), u('').toString());  // FIXME bug on utest
        // single record with/without eol
        Assert.same([["a","b","c"]], u('a,b,c'));
        Assert.same([["a","b","c"]], u('a,b,c${eol}'));
    }

    @:access(format.csv.Reader.readRecord)
    public function test05_IterableApi()
    {
        var reader = new Reader(",", "\"", eol);

        // step by step
        reader.reset('a,b,c${eol}d,e,f', null);
        Assert.isTrue(reader.hasNext());
        Assert.same(["a","b","c"], reader.next());
        Assert.isTrue(reader.hasNext());
        Assert.same(["d","e","f"], reader.next());
        Assert.isFalse(reader.hasNext());

        // empty string
        reader.reset('', null);
        Assert.isTrue(reader.hasNext());
        Assert.same([""], reader.next());
        Assert.isFalse(reader.hasNext());

        // newline terminated document
        reader.reset('a${eol}', null);
        Assert.isTrue(reader.hasNext());
        Assert.same(["a"], reader.next());
        Assert.isFalse(reader.hasNext());

        // `starting` flag updates on other public APIs
        reader.reset('', null); reader.readRecord(); Assert.isFalse(reader.hasNext());
        reader.reset('', null); reader.readAll(); Assert.isFalse(reader.hasNext());

        // iterator & iterable usage
        reader.reset('a,b,c${eol}d,e,f', null);
        Assert.same([["a","b","c"], ["d","e","f"]], [for (record in reader) record]);
        reader.reset('a,b,c${eol}d,e,f', null);
        Assert.same(Lambda.list([["a","b","c"], ["d","e","f"]]), Lambda.list(reader));
    }

    public function test06_Streams()
    {
        var n = new Reader(",", "\"", eol);
        var u = new Utf8Reader(",", "\"", eol);

        function r(reader, hex)
        {
            var d = new BaseCode(Bytes.ofString("0123456789abcdef"));
            var i = new BytesInput(d.decodeBytes(Bytes.ofString(hex)));
            return reader.reset(null, i).readAll();
        }

        var heol = Bytes.ofString(eol).toHex();

        // string/normal reader
        Assert.same([["a","b","c"], ["d","e","f"]], r(n, '612c622c63${heol}642c652c66'));  // a,b,c${eol}d,e,f
        Assert.same([["α","β","γ"], ["d","e","f"]], r(n, 'ceb12cceb22cceb3${heol}642c652c66')); // α,β,γ${eol}d,e,f

        // utf8 reader
        Assert.same([["a","b","c"], ["d","e","f"]], r(u, '612c622c63${heol}642c652c66'));
        Assert.same([["α","β","γ"], ["d","e","f"]], r(u, 'ceb12cceb22cceb3${heol}642c652c66'));
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

