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
        csv                  ::=  "" | record | record eol csv

    Notes:

     - An empty document is parsed as having no records
     - An empty record that would result from a document terminating
       end-of-line sequence is automatically striped
     - Token: null | esc | sep | eol | safe
*/
class Reader {
    static inline var FETCH_SIZE = #if UNIT_TESTING_CSV 4 #else 4096 #end;  // must be larger than any token

    var sep:String;
    var esc:String;
    var eol:Array<String>;  // allowed eol sequences, sorted from longest to shortest
    var inp:Null<Input>;

    var eolsize:Array<Int>;  // cached eol sizes, computed with stringLength
    var buffer:String;
    var pos:Int;
    var bufferOffset:Int;
    var cachedToken:Null<String>;
    var cachedPos:Int;  // invalid if cachedToken == null

    // Used instead of `String.substr`
    // (important for Utf8 support in subclass)
    function substring(str:String, pos:Int, ?length:Null<Int>):String
    {
#if flash
        if (length == null)
            length = str.length;
#end
        return str.substr(pos, length);
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
#if (haxe_ver >= 3.13)
            return bytes.getString(0, got);
#else
            return bytes.readString(0, got);
#end
        } catch (e:Eof) {
            return null;
        }
    }

    function get(p, len)
    {
        var bpos = p - bufferOffset;
        if (bpos + len > stringLength(buffer)) {
            var more = fetchBytes(FETCH_SIZE);
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
        var token = cachedToken, p = pos;
        if (token != null) {
            p = cachedPos;
            skip--;
        }

        while (skip-- >= 0) {
            token = get(p, 1);
            if (token == null)
                break;
            for (i in 0...eol.length) {
                var t = get(p, eolsize[i]);
                if (t == eol[i]) {
                    token = t;
                    break;
                }
            }
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
        if (cur == sep || cur == esc || Lambda.has(eol, cur))
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

    function readRecord()
    {
        var r = [];
        r.push(readField());
        while (peekToken() == sep) {
            nextToken();
            r.push(readField());
        }
        return r;
    }

    /*
       Start or reset the reader in-place with some input data and return it.

       Data can be provided in a string or in a stream.  If both are supplied,
       the reader will first process the entire string, switching automatically
       to the stream when there's no new data left on the string.
    */
    public function open(?string:String, ?stream:Input):Reader
    {
        buffer = string != null ? string : "";
        inp = stream;
        pos = 0;
        bufferOffset = 0;
        cachedToken = null;
        cachedPos = 0;
        return this;
    }

    /*
       Start or reset the reader in-place with some input data and return it.

       Deprecated: use `open(?string, ?stream)` instead.

       Data can be provided in a string or in a stream.  If both are supplied,
       the reader will first process the entire string, switching automatically
       to the stream when there's no new data left on the string.
    */
    @:deprecated("reset(?string, ?stream) has been deprecated; use open(?string, ?stream) instead")
    public inline function reset(?string:String, ?stream:Input):Reader
    {
        return open(string, stream);
    }

    /*
       Read and return all records available.
    */
    public function readAll():Csv
    {
        var r = [];
        var nl;
        while (peekToken() != null) {
            r.push(readRecord());
            nl = nextToken();
            if (nl != null && !Lambda.has(eol, nl))
                throw 'Unexpected "$nl" after record';
        }
        return r;
    }

    /*
       Return whether there are more records to read.

       Part of the iterator/iterable interface.
    */
    public function hasNext():Bool
    {
        return peekToken() != null;
    }

    /*
       Read and return the next record.

       Part of the iterator/iterable interface, its behavior if `hasNext()` is
       false is not specified.
    */
    public function next():Record
    {
        var r = readRecord();
        var nl = nextToken();
        if (nl != null && !Lambda.has(eol, nl))
            throw 'Unexpected "$nl" after record';
        return r;
    }

    /*
       Makes itself an iterable, by returning itself (already an iterator).

       Part of the iterator/iterable interface.
    */
    public function iterator():Reader
    {
        return this;
    }

    /*
       Create a new Reader.

       Creates a native platform string Csv reader.

       Optional parameters:

        - `separator`: 1-char separator string (default: ASCII comma)
        - `escape`: 1-char escape string (default: ASCII double quote)
        - `endOfLine`: allowed end-of-line sequences (default: CRLF or LF)
    */
    public function new(?separator, ?escape, ?endOfLine:Array<String>)
    {

        sep = separator != null ? separator : ",";
        if (stringLength(sep) != 1)
            throw 'Separator string "$sep" not allowed, only single char';

        esc = escape != null ? escape : "\"";
        if (stringLength(esc) != 1)
            throw 'Escape string "$esc" not allowed, only single char';

        eol = endOfLine != null ? endOfLine : ["\r\n", "\n"];
        if (Lambda.has(eol, null) || Lambda.has(eol, ""))
            throw "EOL sequences can't be empty";
        eol.sort(function (a,b) return stringLength(b) - stringLength(a));
        eolsize = eol.map(stringLength);

        open(null, null);
    }

    /*
       Read and return an array with all records in `text`.

       Tip: use this to statically extend Input
    */
    public static function readCsv(stream:Input, ?separator, ?escape, ?endOfLine:Array<String>):Reader
    {
        var p = new Reader(separator, escape, endOfLine);
        p.inp = stream;
        return p;
    }

    /*
       Read and return an array with all records in `text`.

       Tip: use this to statically extend String
    */
    public static function parseCsv(text:String, ?separator, ?escape, ?endOfLine:Array<String>):Array<Record>
    {
        var p = new Reader(separator, escape, endOfLine);
        p.buffer = text;
        return p.readAll();
    }

    /*
       Read and return an array with all records in `text`.

       Deprecated: use `parseCsv(text, ...)` instead.
    */
    @:deprecated("read(text, ...) has been deprecated; use parseCsv(text, ...) instead")
    public static inline function read(text:String, ?separator, ?escape, ?endOfLine:Array<String>):Array<Record>
    {
        return parseCsv(text, separator, escape, endOfLine);
    }
}

