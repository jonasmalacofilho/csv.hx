package format.csv.rdp;

import haxe.io.*;
import haxe.Utf8;

class Utf8Parser extends Parser {
    override function read(p:Int, len:Int):String
    {
        var bpos = p - bufferOffset;
        if (bpos + len > Utf8.length(buffer)) {
            var more = readMore(4);
            if (more != null) {
                buffer = Utf8.sub(buffer, pos - bufferOffset, Utf8.length(buffer)) + more;
                bufferOffset = pos;
                bpos = p - bufferOffset;
            }
        }
        var ret = null;
        while (ret == null) {
            try {
                ret = Utf8.sub(buffer, bpos, len);
            } catch (e:Dynamic) {
                buffer += inp.read(1).toString();
            }
        }
        return ret != "" ? ret : null;
    }

    override function stringLength(str:String):Int
    {
        return Utf8.length(str);
    }
}

