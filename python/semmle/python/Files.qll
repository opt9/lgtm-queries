// Copyright 2017 Semmle Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.


import python

/** A file */
class File extends Container {

    File() {
        files(this, _, _, _, _)
    }

    /** DEPRECATED: Use `getAbsolutePath` instead. */
    string getName() {
        files(this, result, _, _, _)
    }

    /** DEPRECATED: Use `getAbsolutePath` instead. */
    string getFullName() {
        result = getName()
    }

    predicate hasLocationInfo(string filepath, int bl, int bc, int el, int ec) {
        this.getName() = filepath and bl = 0 and bc = 0 and el = 0 and ec = 0
    }

    /** Whether this file is a source code file. */
    predicate fromSource() {
        /* If we start to analyse .pyc files, then this will have to change. */
        any()
    }

    /** Gets a short name for this file (just the file name) */
    string getShortName() {
        exists(string simple, string ext | files(this, _, simple, ext, _) |
             result = simple + ext)
    }

    private int lastLine() {
        result = max(int i | exists(Location l | l.getFile() = this and l.getEndLine() = i))
    }

    /** Whether line n is empty (it contains neither code nor comment). */
    predicate emptyLine(int n) {
        n in [0..this.lastLine()]
        and
        not occupied_line(this, n)
    }

    string getSpecifiedEncoding() {
        exists(Comment c, Location l | 
            l = c.getLocation() and l.getFile() = this |
            l.getStartLine() < 3 and
            result = c.getText().regexpCapture(".*coding[:=]\\s*([-\\w.]+).*", 1)
        )
    }

    string getAbsolutePath() {
        files(this, result, _, _, _)
    }

    /** Gets the URL of this file. */
    string getURL() {
        result = "file://" + this.getAbsolutePath() + ":0:0:0:0"
    }

}

private predicate occupied_line(File f, int n) {
    exists(Location l |
        l.getFile() = f | 
        l.getStartLine() = n
        or
        exists(StrConst s | s.getLocation() = l |
            n in [l.getStartLine() .. l.getEndLine()]
        )
     )
}

/** A folder (directory) */
class Folder extends Container {

    Folder() {
        folders(this, _, _)
    }

    /** DEPRECATED: Use `getAbsolutePath` instead. */
    string getName() {
        folders(this, result, _)
    }

    /** DEPRECATED: Use `getBaseName` instead. */
    string getSimple() {
        folders(this, _, result)
    }

    predicate hasLocationInfo(string filepath, int bl, int bc, int el, int ec) {
        this.getName() = filepath and bl = 0 and bc = 0 and el = 0 and ec = 0
    }

    string getAbsolutePath() {
        folders(this, result, _)
    }

    /** Gets the URL of this folder. */
    string getURL() {
        result = "folder://" + this.getAbsolutePath()
    }

}

/** A container is an abstract representation of a file system object that can
    hold elements of interest. */
abstract class Container extends @container {

    Container getParent() {
        containerparent(result, this)
    }

    /** Gets a child of this container */
    deprecated Container getChild() {
        containerparent(this, result)
    }

    /**
     * Gets a textual representation of the path of this container.
     *
     * This is the absolute path of the container.
     */
    string toString() {
        result = this.getAbsolutePath()
    }

    /** Gets the name of this container */
    abstract string getName();

    /**
     * Gets the relative path of this file or folder from the root folder of the
     * analyzed source location. The relative path of the root folder itself is
     * the empty string.
     *
     * This has no result if the container is outside the source root, that is,
     * if the root folder is not a reflexive, transitive parent of this container.
     */
    string getRelativePath() {
        exists (string absPath, string pref |
            absPath = this.getAbsolutePath() and sourceLocationPrefix(pref) |
            absPath = pref and result = ""
            or
            absPath = pref.regexpReplaceAll("/$", "") + "/" + result and
            not result.matches("/%")
        )
    }

    /** Whether this file or folder is part of the standard library */
    predicate inStdlib() {
        this.inStdlib(_, _)
    }

    /** Whether this file or folder is part of the standard library 
     * for version `major.minor`
     */
    predicate inStdlib(int major, int minor) {
        // https://docs.python.org/library/sys.html#sys.prefix
        exists(string sys_prefix, string version |
            version = major + "." + minor and
            allowable_version(major, minor) and
            py_flags_versioned("sys.prefix", sys_prefix, _) and
            this.getName().regexpMatch(sys_prefix + "/lib/python" + version + ".*")
        )
    }

    /* Standard cross-language API */

    /** Gets a file or sub-folder in this container. */
    Container getAChildContainer() {
        containerparent(this, result)
    }

    /** Gets a file in this container. */
    File getAFile() {
        result = this.getAChildContainer()
    }

    /** Gets a sub-folder in this container. */
    Folder getAFolder() {
        result = this.getAChildContainer()
    }

    /**
     * Gets the absolute, canonical path of this container, using forward slashes
     * as path separator.
     *
     * The path starts with a _root prefix_ followed by zero or more _path
     * segments_ separated by forward slashes.
     *
     * The root prefix is of one of the following forms:
     *
     *   1. A single forward slash `/` (Unix-style)
     *   2. An upper-case drive letter followed by a colon and a forward slash,
     *      such as `C:/` (Windows-style)
     *   3. Two forward slashes, a computer name, and then another forward slash,
     *      such as `//FileServer/` (UNC-style)
     *
     * Path segments are never empty (that is, absolute paths never contain two
     * contiguous slashes, except as part of a UNC-style root prefix). Also, path
     * segments never contain forward slashes, and no path segment is of the
     * form `.` (one dot) or `..` (two dots).
     *
     * Note that an absolute path never ends with a forward slash, except if it is
     * a bare root prefix, that is, the path has no path segments. A container
     * whose absolute path has no segments is always a `Folder`, not a `File`.
     */
    abstract string getAbsolutePath();

    /**
     * Gets the base name of this container including extension, that is, the last
     * segment of its absolute path, or the empty string if it has no segments.
     *
     * Here are some examples of absolute paths and the corresponding base names
     * (surrounded with quotes to avoid ambiguity):
     *
     * <table border="1">
     * <tr><th>Absolute path</th><th>Base name</th></tr>
     * <tr><td>"/tmp/tst.py"</td><td>"tst.py"</td></tr>
     * <tr><td>"C:/Program Files (x86)"</td><td>"Program Files (x86)"</td></tr>
     * <tr><td>"/"</td><td>""</td></tr>
     * <tr><td>"C:/"</td><td>""</td></tr>
     * <tr><td>"D:/"</td><td>""</td></tr>
     * <tr><td>"//FileServer/"</td><td>""</td></tr>
     * </table>
     */
    string getBaseName() {
        result = getAbsolutePath().regexpCapture(".*/(([^/]*?)(?:\\.([^.]*))?)", 1)
    }

    /**
     * Gets the extension of this container, that is, the suffix of its base name
     * after the last dot character, if any.
     *
     * In particular,
     *
     *  - if the name does not include a dot, there is no extension, so this
     *    predicate has no result;
     *  - if the name ends in a dot, the extension is the empty string;
     *  - if the name contains multiple dots, the extension follows the last dot.
     *
     * Here are some examples of absolute paths and the corresponding extensions
     * (surrounded with quotes to avoid ambiguity):
     *
     * <table border="1">
     * <tr><th>Absolute path</th><th>Extension</th></tr>
     * <tr><td>"/tmp/tst.py"</td><td>"py"</td></tr>
     * <tr><td>"/tmp/.gitignore"</td><td>"gitignore"</td></tr>
     * <tr><td>"/bin/bash"</td><td>not defined</td></tr>
     * <tr><td>"/tmp/tst2."</td><td>""</td></tr>
     * <tr><td>"/tmp/x.tar.gz"</td><td>"gz"</td></tr>
     * </table>
     */
    string getExtension() {
        result = getAbsolutePath().regexpCapture(".*/([^/]*?)(\\.([^.]*))?", 3)
    }

    /**
     * Gets the stem of this container, that is, the prefix of its base name up to
     * (but not including) the last dot character if there is one, or the entire
     * base name if there is not.
     *
     * Here are some examples of absolute paths and the corresponding stems
     * (surrounded with quotes to avoid ambiguity):
     *
     * <table border="1">
     * <tr><th>Absolute path</th><th>Stem</th></tr>
     * <tr><td>"/tmp/tst.py"</td><td>"tst"</td></tr>
     * <tr><td>"/tmp/.gitignore"</td><td>""</td></tr>
     * <tr><td>"/bin/bash"</td><td>"bash"</td></tr>
     * <tr><td>"/tmp/tst2."</td><td>"tst2"</td></tr>
     * <tr><td>"/tmp/x.tar.gz"</td><td>"x.tar"</td></tr>
     * </table>
     */
    string getStem() {
        result = getAbsolutePath().regexpCapture(".*/([^/]*?)(?:\\.([^.]*))?", 1)
    }

    File getFile(string baseName) {
        result = this.getAFile() and
        result.getBaseName() = baseName
    }

    Folder getFolder(string baseName) {
        result = this.getAFolder() and
        result.getBaseName() = baseName
    }

    Container getParentContainer() {
        this = result.getAChildContainer()
    }

    /**
     * Gets a URL representing the location of this container.
     *
     * For more information see https://lgtm.com/docs/ql/locations#providing-urls.
     */
    abstract string getURL();

}

private predicate allowable_version(int major, int minor) {
    major = 2 and minor in [6..7]
    or
    major = 3 and minor in [3..6]
}

class Location extends @location {

    /** Gets the file for this location */
    File getFile() {
        locations_default(this, result, _, _, _, _)
        or
        exists(Module m | locations_ast(this, m, _, _, _, _) |
            result = m.getFile()
        )
    }

    /** Gets the start line of this location */
    int getStartLine() {
        locations_default(this, _, result, _, _, _)
        or locations_ast(this,_,result,_,_,_)
    }

    /** Gets the start column of this location */
    int getStartColumn() {
        locations_default(this, _, _, result, _, _)
        or locations_ast(this, _, _, result, _, _)
    }

    /** Gets the end line of this location */
    int getEndLine() {
        locations_default(this, _, _, _, result, _)
        or locations_ast(this, _, _, _, result, _)
    }

    /** Gets the end column of this location */
    int getEndColumn() {
        locations_default(this, _, _, _, _, result)
        or locations_ast(this, _, _, _, _, result)
    }

    string toString() {
        result = this.getFile().getName() + ":" + this.getStartLine().toString()
    }

    predicate hasLocationInfo(string filepath, int bl, int bc, int el, int ec) {
        exists(File f | f.getName() = filepath |
            locations_default(this, f, bl, bc, el, ec)
            or
            exists(Module m | m.getFile() = f |
                locations_ast(this, m, bl, bc, el, ec))
            )
    }

}

/** A non-empty line in the source code */
class Line extends @py_line {

    predicate hasLocationInfo(string filepath, int bl, int bc, int el, int ec) {
        exists(Module m | m.getFile().getName() = filepath and
            el = bl and bc = 1 and
            py_line_lengths(this, m, bl, ec))
    }

    string toString() {
        exists(Module m | py_line_lengths(this, m, _, _) |
            result = m.getFile().getShortName() + ":" + this.getLineNumber().toString()
        )
    }

    /** Gets the line number of this line */
    int getLineNumber() {
        py_line_lengths(this, _, result, _)
    }

    /** Gets the length of this line */
    int getLength() {
        py_line_lengths(this, _, _, result)
    }

    /** Gets the file for this line */
    Module getModule() {
        py_line_lengths(this, result, _, _)
    }

}

/** A syntax error. Note that if there is a syntax error in a module,
   much information about that module will be lost */
class SyntaxError extends Location {

    SyntaxError() {
        py_syntax_error_versioned(this, _, major_version().toString())
    }

    string toString() {
        result = "Syntax Error"
    }

    /** Gets the message corresponding to this syntax error */
    string getMessage() {
        py_syntax_error_versioned(this, result, major_version().toString())
    }

}

/** An encoding error. Note that if there is an encoding error in a module,
   much information about that module will be lost */
class EncodingError extends SyntaxError {

    EncodingError() {
        /* Leave spaces around 'decode' in unlikely event it occurs as a name in a syntax error */
        this.getMessage().toLowerCase().matches("% decode %")
    }

    string toString() {
        result = "Encoding Error"
    }

}


