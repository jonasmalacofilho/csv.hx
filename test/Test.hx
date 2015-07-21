import format.csv.*;
import haxe.crypto.BaseCode;
import haxe.io.*;
import utest.*;
import utest.ui.Report;

class BaseSuite {
    var allowedEol:Array<String>;
    var eol:String;

    public function test00_Examples()
    {
        var csv = "a,b,c\n1,2,3";
        trace("Example 1:");

        trace(Reader.read(csv));       // native strings, default control strings ,"\n
        trace(Utf8Reader.read(csv));   // ensure proper Utf8 handling (not always necessary)
        trace(Reader.read(csv, "|"));  // use | for separator


        var input = new StringInput(csv);
        trace("Example 2 - a:");

        // create a reader
        var reader = new Reader();  // optionally specify different separator, escape or EOL strings

        // reset the reader with the stream
        reader.reset(null, input);  // a string or a combination of both string and input can also be used
                                    // to reset; the reader will always try to start with the string and
                                    // then pass to the stream

        // use the iterable interface
        for (record in reader)
            trace(record);  // do some work, without first having to read the entire stream


        reader.reset(null, input = new StringInput(csv));
        trace("Example 2 - b:");

        // OR read everything
        trace(reader.readAll());

        Assert.isTrue(true);
    }

    public function test01_NormalRecordReading()
    {
        var reader = new Reader(",", "\"", allowedEol);
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

        var n = new Reader(",", "\"", allowedEol);
        var u = new Utf8Reader(",", "\"", allowedEol);

        Assert.same(["α","β","γ"], r(n, 'α,β,γ'));
        Assert.same(["α","β","γ"], r(u, 'α,β,γ'));
    }

    public function test03_UnsafeUtf8RecordReading()
    {
        function r(reader, str)
        {
            return reader.reset(str, null).next();
        }

#if (js || java || cs || python || flash)
        // on targets where String already has unicode support, the Utf8Reader
        // shouldn't be necessary
        var n = new Reader("➔", "✍", allowedEol);
        Assert.same(["a","b","c"], r(n, 'a➔b➔c'));
        Assert.same(["a","b","c"], r(n, '✍a✍➔b➔c'));
        Assert.same(["α","β","γ"], r(n, 'α➔β➔γ'));
#end
        var u = new Utf8Reader("➔", "✍", allowedEol);
        Assert.same(["a","b","c"], r(u, 'a➔b➔c'));
        Assert.same(["a","b","c"], r(u, '✍a✍➔b➔c'));
        Assert.same(["α","β","γ"], r(u, 'α➔β➔γ'));
    }

    public function test04_Read()
    {
        var n = Reader.read.bind(_, ",", "\"", allowedEol);
        var u = Utf8Reader.read.bind(_, ",", "\"", allowedEol);

        // string/normal reader
        // multiple records
        Assert.same([["a","b","c"], ["d","e","f"]], n('a,b,c${eol}d,e,f'));
        // empty string
        Assert.same([], n(''));
        // almost empty string
        Assert.same([[""]], n('$eol'));
        // single record with/without eol
        Assert.same([["a","b","c"]], n('a,b,c'));
        Assert.same([["a","b","c"]], n('a,b,c${eol}'));
        // empty fields
        Assert.same([["","",""],["","",""]], n('"","",""${eol},,'));

        // utf8 reader
        // multiple records
        Assert.same([["a","b","c"], ["d","e","f"]], u('a,b,c${eol}d,e,f'));
        // empty string
        Assert.same([], u(''));
        // almost empty string
        Assert.same([[""]], u('$eol'));
        // single record with/without eol
        Assert.same([["a","b","c"]], u('a,b,c'));
        Assert.same([["a","b","c"]], u('a,b,c${eol}'));
        // empty fields
        Assert.same([["","",""],["","",""]], u('"","",""${eol},,'));
    }

    @:access(format.csv.Reader.readRecord)
    public function test05_IterableApi()
    {
        var reader = new Reader(",", "\"", allowedEol);

        // step by step
        reader.reset('a,b,c${eol}d,e,f', null);
        Assert.isTrue(reader.hasNext());
        Assert.same(["a","b","c"], reader.next());
        Assert.isTrue(reader.hasNext());
        Assert.same(["d","e","f"], reader.next());
        Assert.isFalse(reader.hasNext());

        // empty string
        reader.reset('', null);
        Assert.isFalse(reader.hasNext());

        // almost empty string
        reader.reset('$eol', null);
        Assert.isTrue(reader.hasNext());
        Assert.same([""], reader.next());
        Assert.isFalse(reader.hasNext());

        // newline terminated document
        reader.reset('a${eol}', null);
        Assert.isTrue(reader.hasNext());
        Assert.same(["a"], reader.next());

        // iterator & iterable usage
        reader.reset('a,b,c${eol}d,e,f', null);
        Assert.same([["a","b","c"], ["d","e","f"]], [for (record in reader) record]);
        reader.reset('a,b,c${eol}d,e,f', null);
        Assert.same(Lambda.list([["a","b","c"], ["d","e","f"]]), Lambda.list(reader));
    }

    public function test06_Streams()
    {
        var n = new Reader(",", "\"", allowedEol);
        var u = new Utf8Reader(",", "\"", allowedEol);

        function r(reader, hex)
        {
            var d = new BaseCode(Bytes.ofString("0123456789abcdef"));
            var i = new BytesInput(d.decodeBytes(Bytes.ofString(hex)));
            return reader.reset(null, i).readAll();
        }

        var heol = Bytes.ofString(eol).toHex();

        // ascii
        Assert.same([["a","b","c"], ["d","e","f"]], r(n, '612c622c63${heol}642c652c66'));  // a,b,c${eol}d,e,f
        Assert.same([["a","b","c"], ["d","e","f"]], r(u, '612c622c63${heol}642c652c66'));

        // utf8
        Assert.same([["α","β","γ"], ["d","e","f"]], r(u, 'ceb12cceb22cceb3${heol}642c652c66'));

        // utf8 with string/normal reader
#if !(js || java || cs || python || flash)
        // targets where native String has unicode support can't (all) read a
        // Utf8 stream with the native String Reader; invalid Utf8 strings can't
        // be constructed on these targets
        Assert.same([["α","β","γ"], ["d","e","f"]], r(n, 'ceb12cceb22cceb3${heol}642c652c66')); // α,β,γ${eol}d,e,f
#end
    }

    public function test07_Exhaustion()
    {
        var reader = new Reader(",", "\"", allowedEol);

        reader.reset('', null);
        Assert.same([], reader.readAll());
        Assert.isFalse(reader.hasNext());
        Assert.same([], reader.readAll());

        reader.reset('$eol', null);
        Assert.same([[""]], reader.readAll());
        Assert.isFalse(reader.hasNext());
        Assert.same([], reader.readAll());

        reader.reset('a,b,c', null);
        Assert.same([["a","b","c"]], reader.readAll());
        Assert.isFalse(reader.hasNext());
        Assert.same([], reader.readAll());

        reader.reset('a,b,c$eol', null);
        Assert.same([["a","b","c"]], reader.readAll());
        Assert.isFalse(reader.hasNext());
        Assert.same([], reader.readAll());
    }
}

class Suite01_NixEol extends BaseSuite {
    public function new()
    {
        this.eol = "\n";
        this.allowedEol = [this.eol];
    }
}

class Suite02_WindowsEol extends BaseSuite {
    public function new()
    {
        this.eol = "\r\n";
        this.allowedEol = [this.eol];
    }
}

class Suite03_NixMixedEol extends BaseSuite {
    public function new()
    {
        this.eol = "\n";
        this.allowedEol = ["\r\n", "\n"];
    }
}

class Suite04_WindowsMixedEol extends BaseSuite {
    public function new()
    {
        this.eol = "\r\n";
        this.allowedEol = ["\r\n", "\n"];
    }
}

class Test {
    static function main()
    {
        var r = new Runner();
        r.addCase(new Suite01_NixEol());
        r.addCase(new Suite02_WindowsEol());
        r.addCase(new Suite03_NixMixedEol());
        r.addCase(new Suite04_WindowsMixedEol());
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

