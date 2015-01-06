import haxe.Utf8;

typedef Field = String;
typedef Record = Array<Field>;

/*
    The grammar is:
 
    csv              ::=  TODO
    record           ::=  <> | field | field sep record
    field            ::=  esc escaped_string esc | unescaped_string
    escaped_string   ::=  <> | esc esc escaped_string | esc sep escaped_string | safe escaped_string
    unescaped_string ::=  <> | safe unescaped_string
    safe             ::=  !esc | !sep
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

    function precord()
    {
        var r = [];
        r.push(pfield());
        if (peek() == sep) {
            next();
            r = r.concat(precord());
        }
        return r;
    }

    function pfield()
    {
        var buf = new StringBuf();
        var cur = peek();
        if (cur == esc) {
            next();
            var s = pescstr(buf);
            var fi = next();
            if (fi != esc)
                throw 'Assert: $fi';  // FIXME: replace by rewind
            return s;
        } else {
            return punescstr(buf);
        }
    }

    function pescesc()
    {
        var cur = peek();
        var nx = peek(1);
        if (cur != esc || nx != esc)
            return null;
        next(1);
        return esc;
    }

    function pescsep()
    {
        var cur = peek();
        if (cur != sep)
            return null;
        next();
        return sep;
    }

    function pescstr(buf:StringBuf)
    {
        var x = psafe();
        if (x == null)
            x = pescesc();
        if (x == null)
            x = pescsep();
        if (x != null) {
            buf.add(x);
            return pescstr(buf);
        }
        return buf.toString();
    }

    function punescstr(buf:StringBuf)
    {
        var x = psafe();
        if (x != null) {
            buf.add(x);
            return punescstr(buf);
        }
        return buf.toString();
    }

    function psafe()
    {
        var cur = peek();
        if (cur == sep || cur == esc)
            return null;
        next();
        return cur;
    }

    function run()
    {
        // FIXME: read the other records
        return [precord()];
    }

    public static function parse(str:String, ?sep=",", ?esc="\"")
    {
        var p = new Parser(str, sep, esc);
        return p.run();
    }

}

