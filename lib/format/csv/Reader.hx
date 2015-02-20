package format.csv;

import format.csv.Data;
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

        safe_char            ::=  !( esc | sep | eol )
        escaped_char         ::=  safe | esc esc | sep | eol
        string               ::=  "" | safe non_escaped_string
        escaped_string       ::=  "" | escaped escaped_string
        field                ::=  esc escaped_string esc | non_escaped_string
        record               ::=  field | field sep record
        csv                  ::=  record | record eol csv

    Notes:

     - The resulting empty record after a terminating end-of-line sequence in a
       text is automatically striped.
     - Token: null | esc | sep | eol | safe
*/
class Reader {
    var sep:String;
    var esc:String;
    var eol:String;
    var inp:Null<Input>;

    var eolsize:Int;  // cached eol size, computed with stringLength
    var buffer:String;
    var pos:Int;
    var bufferOffset:Int;
    var cachedToken:Null<String>;
    var cachedPos:Int;  // invalid if cachedToken == null

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

    function fetchBytes(n:Int):Null<String>
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

    function get(p, len)
    {
        var bpos = p - bufferOffset;
        if (bpos + len > stringLength(buffer)) {
            var more = fetchBytes(4);
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
        var token = cachedToken, p = cachedPos;
        if (token == null)
            cachedPos = pos;
        else
            skip--;

        while (skip-- >= 0) {
            token = get(p, eolsize) == eol ? eol : get(p, 1);
            if (token == null)
                break;
            p += stringLength(token);
            if (cachedToken == null) {
                cachedToken = token;
                cachedPos = p;
            }
        }
        return token;
    }

    function nextToken()
    {
        var ret = peekToken();
        if (ret == null)
            return null;
        pos = cachedPos;
        cachedToken = null;
        return ret;
    }

    function readSafeChar()
    {
        var cur = peekToken();
        if (cur == sep || cur == esc || cur == eol)
            return null;
        return nextToken();
    }

    function readEscapedChar()
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

    function readEscapedString()
    {
        var buf = new StringBuf();
        var x = readEscapedChar();
        while (x != null) {
            buf.add(x);
            x = readEscapedChar();
        }
        return buf.toString();
    }

    function readString()
    {
        var buf = new StringBuf();
        var x = readSafeChar();
        while (x != null) {
            buf.add(x);
            x = readSafeChar();
        }
        return buf.toString();
    }

    function readField()
    {
        var cur = peekToken();
        if (cur == esc) {
            nextToken();
            var s = readEscapedString();
            var fi = nextToken();
            if (fi != esc)
                throw 'Missing $esc at the end of escaped field ${s.length>15 ? s.substr(0,10)+"[...]" : s}';
            return s;
        } else {
            return readString();
        }
    }

    /*
       Reset the reader with some input data.

       Data can be provided in a string or in a stream.  If both are supplied,
       the reader will first process the entire string, switching automatically
       to the stream when there's no new data left on the string.
    */
    public function reset(?string:String, ?stream:Input):Void
    {
        buffer = string != null ? string : "";
        inp = stream;
        pos = 0;
        bufferOffset = 0;
        cachedToken = null;
        cachedPos = 0;
        starting = true;
    }

    /*
       Create a new Reader.

       Creates a native String Csv reader.

       Params:

        - `separator`: 1-char separator string
        - `escape`: 1-char escape (or "quoting") string
        - `endOfLine`: end-of-line sequence string
    */
    public function new(separator:String, escape:String, endOfLine:String)
    {
        if (stringLength(separator) != 1)
            throw 'Separator string "$separator" not allowed, only single char';
        if (stringLength(escape) != 1)
            throw 'Escape string "$escape" not allowed, only single char';
        if (stringLength(endOfLine) < 1)
            throw "EOL sequence can't be empty";

        sep = separator;
        esc = escape;
        eol = endOfLine;
        eolsize = stringLength(eol);

        reset(buffer, null);
    }

    /*
       Read and return a single record.

       This will process the input until a separator or an end-of-line is
       found.
    */
    public function readRecord():Record
    {
        starting = false;
        var r = [];
        r.push(readField());
        while (peekToken() == sep) {
            nextToken();
            r.push(readField());
        }
        return r;
    }

    /*
       Read and return all records available.
    */
    public function readAll():Csv
    {
        var r = [];
        r.push(readRecord());
        var nl = nextToken();
        while (nl == eol) {
            if (peekToken() != null)
                r.push(readRecord());  // don't append an empty record for eol terminating string
            nl = nextToken();
        }
        if (peekToken() != null)
            throw 'Unexpected "${peekToken()}" after record';
        return r;
    }

    var starting:Bool;

    public function hasNext()
    {
        return starting || (peekToken() != null && peekToken(1) != null);
    }

    public function next()
    {
        if (!starting) {
            var nl = nextToken();
            if (nl != eol)
                throw 'Unexpected "${peekToken()}" after record';
        }
        return readRecord();
    }

    public function iterator()
    {
        return this;
    }

    /*
       Read and return all records in `text`.
    */
    public static function read(text:String, ?separator=",", ?escape="\"", ?endOfLine="\n"):Array<Record>
    {
        var p = new Reader(separator, escape, endOfLine);
        p.buffer = text;
        return p.readAll();
    }
}

