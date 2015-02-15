package format.csv.rdp;

import format.csv.rdp.Types;

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
    var str:String;
    var sep:String;
    var esc:String;
    var eol:String;

    var pos:Int;
    var len:Int;  // cached str size, computed with strlen
    var eolsize:Int;  // cached eol size, computed with strlen
    var peekedToken:String;  // cached result of peekToken (only if skik==0)

    // Used `String.substr` equivalent or replacement
    function substr(str:String, pos:Int, len:Int):String
    {
        return str.substr(pos, len);
    }

    // Used `String.length` replacement
    function strlen(str:String):Int
    {
        return str.length;
    }

    function new(str, sep, esc, eol)
    {
        if (strlen(sep) != 1)
            throw 'Separator string "$sep" not allowed, only single char';
        if (strlen(esc) != 1)
            throw 'Escape string "$esc" not allowed, only single char';
        if (strlen(eol) < 1)
            throw "EOL sequence can't be empty";
        if (StringTools.startsWith(eol, esc))
            throw 'EOL sequence can\'t start with the esc character ($esc)';

        this.sep = sep;
        this.esc = esc;
        this.eol = eol;
        this.eolsize = strlen(eol);
        this.str = str;
        len = strlen(str);
        pos = 0;
    }

    function peekToken(?skip=0)
    {
        var s = skip, p = pos, ret = null;
        while (s-- >= 0) {
            if (p >= len) {
                ret = null;
                break;
            }
            ret = substr(str, p, eolsize) == eol ? eol : substr(str, p, 1);
            p += strlen(ret);
        }
        peekedToken = skip == 0 ? ret : null;
        return ret;
    }

    function nextToken()
    {
        var ret = peekedToken;
        if (ret == null)
            ret = peekToken();
        peekedToken = null;

        if (ret == null)
            return null;
        pos += strlen(ret);
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
        var p = new Parser(text, separator, escape, endOfLine);
        return p.records();
    }

    public static function parseUtf8(text:String, ?separator=",", ?escape="\"", ?endOfLine="\n"):Array<Record>
    {
        var p = new Utf8Parser(text, separator, escape, endOfLine);
        return p.records();
    }
}

