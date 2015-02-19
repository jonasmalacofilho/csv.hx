package format.csv.rdp;

import format.csv.rdp.Types;
import haxe.io.*;

/*
    A recursive descent parser for CSV strings

    The Grammar
    -----------

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

     - The resulting empty record after a terminating end-of-line sequence in a
       text is automatically striped.
     - Token: null | esc | sep | eol | safe
*/
class Parser {
    var sep:String;
    var esc:String;
    var eol:String;
    var inp:Null<Input>;

    var pos:Int;
    var eolsize:Int;  // cached eol size, computed with stringLength
    var buffer:String;
    var bufferOffset:Int;
    var tokenCache:List<{ token:String, pos:Int }>;  // cached results of peekToken

    // Used instead of `String.substr`
    // (important for Utf8 support in subclass)
    function substring(str:String, pos:Int, ?len:Null<Int>):String
    {
        return str.substr(pos, len);
    }

    // Used instead of `String.length`
    // (important for Utf8 support in subclass)
    function stringLength(str:String):Int
    {
        return str.length;
    }

    function new(sep, esc, eol, inp)
    {
        if (stringLength(sep) != 1)
            throw 'Separator string "$sep" not allowed, only single char';
        if (stringLength(esc) != 1)
            throw 'Escape string "$esc" not allowed, only single char';
        if (stringLength(eol) < 1)
            throw "EOL sequence can't be empty";
        if (StringTools.startsWith(eol, esc))
            throw 'EOL sequence can\'t start with the esc character ($esc)';

        this.sep = sep;
        this.esc = esc;
        this.eol = eol;
        this.inp = inp;

        this.eolsize = stringLength(eol);
        tokenCache = new List();

        buffer = "";
        pos = 0;
        bufferOffset = 0;
    }

    function readMore(n:Int)
    {
        if (inp == null)
            return null;

        try {
            var bytes = Bytes.alloc(n);
            var got = inp.readBytes(bytes, 0, n);
            return bytes.getString(0, got);
        } catch (e:Eof) {
            return null;
        }
    }

    function read(p:Int, len:Int):String
    {
        var bpos = p - bufferOffset;
        if (bpos + len > stringLength(buffer)) {
            var more = readMore(4);
            if (more != null) {
                buffer = substring(buffer, pos - bufferOffset) + more;
                bufferOffset = pos;
                bpos = p - bufferOffset;
            }
        }
        var ret = substring(buffer, bpos, len);
        return ret != "" ? ret : null;
    }

    function peekToken(?skip=0)
    {
        var peek = skip + 1;

        var token = null, p = pos;
        for (t in tokenCache) {
            token = t.token;
            p = t.pos;
            peek--;
            if (peek <= 0)
                break;
        }

        while (peek-- > 0) {
            token = read(p, eolsize) == eol ? eol : read(p, 1);
            if (token == null)
                break;
            p += stringLength(token);
            tokenCache.add({ token : token, pos : p });
        }
        return token;
    }

    function nextToken()
    {
        var ret = peekToken();
        if (ret == null)
            return null;
        pos = tokenCache.pop().pos;
        return ret;
    }

    function safe()
    {
        var cur = peekToken();
        if (cur == sep || cur == esc || cur == eol)
            return null;
        return nextToken();
    }

    function escaped()
    {
        var cur = peekToken();
        // It follows from the grammar that the only forbidden result is an isolated escape
        if (cur == esc) {
            if (peekToken(1) != esc)
                return null;
            nextToken();  // skip the first esc
        }
        return nextToken();
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
        var cur = peekToken();
        if (cur == esc) {
            nextToken();
            var s = escapedString();
            var fi = nextToken();
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
        while (peekToken() == sep) {
            nextToken();
            r.push(field());
        }
        return r;
    }

    function records()
    {
        var r = [];
        r.push(record());
        var nl = nextToken();
        while (nl == eol) {
            if (peekToken() != null)
                r.push(record());  // don't append an empty record for eol terminating string
            nl = nextToken();
        }
        if (peekToken() != null)
            throw 'Unexpected "${peekToken()}" after record';
        return r;
    }

    public static function parse(text:String, ?separator=",", ?escape="\"", ?endOfLine="\n"):Array<Record>
    {
        var p = new Parser(separator, escape, endOfLine, null);
        p.buffer = text;
        return p.records();
    }

    public static function parseUtf8(text:String, ?separator=",", ?escape="\"", ?endOfLine="\n"):Array<Record>
    {
        var p = new Utf8Parser(separator, escape, endOfLine, null);
        p.buffer = text;
        return p.records();
    }
}

