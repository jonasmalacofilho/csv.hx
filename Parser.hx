import haxe.Utf8;

typedef Field = String;
typedef Record = Array<Field>;

/*
    TODO Missing newline handling and multiple records

    The Grammar
 
    Terminals:

        sep                       separator string, usually `,`
        esc                       escape string, usually `"`

    Non-terminals:

        safe                 ::=  !( esc | sep )
        escaped              ::=  safe | esc esc | sep
        non_escaped_string   ::=  "" | safe non_escaped_string
        escaped_string       ::=  "" | escaped escaped_string
        field                ::=  esc escaped_string esc | non_escaped_string
        record               ::=  field | field sep record
        csv                  ::=  TODO
*/
class Parser {

    var sep:String;
    var esc:String;
    var str:String;
    var len:Int;
    var pos:Int;

    function new(str, sep, esc)
    {
        this.sep = sep;
        this.esc = esc;
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
        if (cur == sep || cur == esc)
            return null;
        next();
        return cur;
    }

    function escapedEsc()
    {
        var cur = peek();
        var nx = peek(1);
        if (cur != esc || nx != esc)
            return null;
        next(1);
        return esc;
    }

    function escapedSep()
    {
        var cur = peek();
        if (cur != sep)
            return null;
        next();
        return sep;
    }

    function escaped()
    {
        var x = safe();
        if (x == null)
            x = escapedEsc();
        if (x == null)
            x = escapedSep();
        return x;
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
        // FIXME: read the other records
        return [record()];
    }

    public static function parse(str:String, ?sep=",", ?esc="\"")
    {
        var p = new Parser(str, sep, esc);
        return p.records();
    }

}

