import haxe.Utf8;

typedef Field = String;
typedef Record = Array<Field>;

/*
    TODO Missing newline handling and multiple records

    The Grammar
 
    Terminals:

        sep                       separator string, usually `,`
        esc                       escape string, usually `"`
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

    function safe()
    {
        var cur = peek();
        if (cur == sep || cur == esc || cur == eol)
            return null;
        return next();
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
        var n = next();
        while (n != null) {
            if (n != eol)
                throw 'Unexpected "$n" after record';
            if (peek() == null)
                break;  // don't append an empty record for eol terminating string
            r.push(record());
            n = next();
        }
        return r;
    }

    public static function parse(text:String, ?separator=",", ?escape="\"", ?endOfLine="\n"):Array<Record>
    {
        var p = new Parser(text, separator, escape, endOfLine);
        return p.records();
    }

}

