# Markdown API links

Scripts to add links to API documentation to a markdown document.

First, run `Create-HelpReferences.ps1`, which will look for text in the document that looks like
```Identifier``` that don't already have a link around them. It add look for matching references in
a directory with help files (created with [Sandcastle Help File Builder](https://github.com/EWSoftware/SHFB),
and those to a json file. Any identifiers it can't resolve will be set to "!UNKNOWN!" so you can
find them and resolve them manually.

`Create-HelpReferences.ps1` can also be used for C++ doxygen documentation. In that case, pass the
`-Cpp` and `-CppNamespace` arguments, and use the doxygen tag file instead of a directory for the
`-HelpPath`.

Link targets in the json will use the file base name only. Set the `#prefix` and `#suffix` values to
create valid links.

Set an identifier to `null` in the json file if you don't want to create a link. You can also start
a value with `#` to use the alternate `#apiPrefix`, which I use to link to official .Net documentation.

Then run `Add-HelpLinks.ps1` to insert links. It'll ask you to confirm for each one, or to pick a
target if there are multiple. Links are inserted as reference-style links to keep the text as clean
as possible.

`Check-Links.ps1` checks if all link targets in a document are valid, including anchors for links
to other local markdown files. It can't handle links that span more than one line.

This was used to add API links to the documentation for [Ookii.CommandLine](https://github.com/SvenGroot/Ookii.CommandLine/blob/main/docs/refs.json).
