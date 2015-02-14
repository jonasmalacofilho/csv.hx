import haxe.Utf8;

typedef Field = String;
typedef Record = Array<Field>;

/*
    TODO Missing newline handling and multiple records

    The Grammar
 
    Terminals:

        sep                       separator character, usually `,`
        esc                       escape character, usually `"`
        eol                       end-on-line sequence, usually `\n` or `\r\n`

    Non-terminals:

        safe                 ::=  !( esc | sep | eol )
        escaped              ::=  safe | esc esc | sep | eol
        non_escaped_string   ::=  "" | safe non_escaped_string
        escaped_string       ::=  "" | escaped escaped_string
        field                ::=  esc escaped_string esc | non_escaped_string
        record               ::=  field | field sep record
        csv                  ::=  record | record eol csv

    Notes:

        The resulting empty record after a terminating end-of-line sequence in
        a text is automatically striped.
*/
class Parser {

    var sep:String;
    var esc:String;
    var eol:String;
    var str:String;
    var len:Int;
    var pos:Int;

    function new(str, sep, esc, eol)
    {
        if (Utf8.length(sep) != 1)
            throw 'Separator string "$sep" not allowed, only single char';
        if (Utf8.length(esc) != 1)
            throw 'Escape string "$esc" not allowed, only single char';
        if (Utf8.length(eol) < 1)
            throw "EOL sequence can't be empty";
        if (StringTools.startsWith(eol, esc))
            throw 'EOL sequence can\'t start with the esc character ($esc)';

        this.sep = sep;
        this.esc = esc;
        this.eol = eol;
        this.str = str;
        len = Utf8.length(str);
        pos = 0;
    }

    function peek(?skip=0)
    {
        if (pos + skip >= len)
            return null;
        return Utf8.sub(str, pos + skip, 1);
    }

    function next(?skip=0)
    {
        var cur = peek(skip);
        if (peek != null)
            pos += skip + 1;
        return cur;
    }

    function rewind(n:Int)
    {
        pos -= n;
    }

    function endOfLine()
    {
        for (i in 0...Utf8.length(eol)) {
            if (peek(i) != Utf8.sub(eol, i, 1))
                return null;
        }
        next(Utf8.length(eol) - 1);
        return eol;
    }

    function safe()
    {
        var cur = peek();
        if (cur == sep || cur == esc) {
            return null;
        } else if (endOfLine() != null) {
            rewind(Utf8.length(eol));
            return null;
        } else {
            return next();
        }
    }

    function escaped()
    {
        var cur = peek();
        // It follows from the grammar that the only forbidden result is an isolated escape
        if (cur == esc) {
            if (peek(1) != esc)
                return null;
            return next(1);
        }
        return next();
    }

    function escapedString()
    {
        var buf = new StringBuf();
        var x = escaped();
        while (x != null) {
            buf.add(x);
            x = escaped();
        }
        return buf.toString();
    }

    function nonEscapedString()
    {
        var buf = new StringBuf();
        var x = safe();
        while (x != null) {
            buf.add(x);
            x = safe();
        }
        return buf.toString();
    }

    function field()
    {
        var cur = peek();
        if (cur == esc) {
            next();
            var s = escapedString();
            var fi = next();
            if (fi != esc)
                throw 'Missing $esc at the end of escaped field ${s.length>15 ? s.substr(0,10)+"[...]" : s}';
            return s;
        } else {
            return nonEscapedString();
        }
    }

    function record()
    {
        var r = [];
        r.push(field());
        while (peek() == sep) {
            next();
            r.push(field());
        }
        return r;
    }

    function records()
    {
        var r = [];
        r.push(record());
        var nl = endOfLine();
        while (nl != null) {
            if (peek() == null)
                break;  // don't append an empty record for eol terminating string
            r.push(record());
            nl = endOfLine();
        }
        if (peek() != null)
            throw 'Unexpected "${peek()}" after record';
        return r;
    }

    public static function parse(text:String, ?separator=",", ?escape="\"", ?endOfLine="\n"):Array<Record>
    {
        var p = new Parser(text, separator, escape, endOfLine);
        return p.records();
    }

}

