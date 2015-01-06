import Parser.parse;

class Test {

    static function main()
    {
        trace("Hello!");
        trace(parse("a,b,c"));
        trace(parse('"a",b,c'));
        trace(parse('"a"",""a",b,c'));
    }

}

