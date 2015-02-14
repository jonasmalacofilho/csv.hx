import utest.Assert;
import utest.Runner;
import utest.ui.Report;

@:access(Parser)
class Test {
    static inline var SEP = ",";
    static inline var ESC = "\"";
    static inline var NEWLINE = "\n";

    function new() {}

    function parser(text)
    {
        return new Parser(text, SEP, ESC, NEWLINE);
    }

    function parseRecord(text)
    {
        return "[" + parser(text).record().join("|") + "]";
    }

    function parseCsv(text)
    {
        return "{" + Parser.parse(text, SEP, ESC, NEWLINE)
            .map(function (x) return "["+x.join("|")+"]").join(";") + "}";
    }

    function testParseRecord()
    {
        Assert.same('[a|b|c]', parseRecord('a,b,c'));
        // escaping
        Assert.same('[a|b|c]', parseRecord('"a",b,c'));
        Assert.same('["a"|b|c]', parseRecord('"""a""",b,c'));
        Assert.same('[a"a|b|c]', parseRecord('"a""a",b,c'));  // esc
        Assert.same('[a,a|b|c]', parseRecord('"a,a",b,c'));  // sep
        Assert.same('[a\na|b|c]', parseRecord('"a\na",b,c'));  // eol
        Assert.same('[a",\n"a|b|c]', parseRecord('"a"",\n""a",b,c'));  // esc, sep & eol
        // empty fields
        Assert.same('[||]', parseRecord(',,'));
        Assert.same('[||]', parseRecord('"","",""'));
    }

    function testParseCsv()
    {
        // multiple records
        Assert.same('{[a|b|c];[d|e|f]}', parseCsv('a,b,c\nd,e,f'));
        // empty string
        Assert.same('{[]}', parseCsv(''));
        // single record with/without eol
        Assert.same('{[a|b|c]}', parseCsv('a,b,c'));
        Assert.same('{[a|b|c]}', parseCsv('a,b,c\n'));
    }

    static function main()
    {
        var r = new Runner();
        r.addCase(new Test());
        Report.create(r);
        r.run();
    }
}

