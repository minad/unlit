> {-# LANGUAGE OverloadedStrings #-}
> module Unlit.Text (
>   unlit, relit
>   , Style, parseStyle
>   , WhitespaceMode(..), parseWhitespaceMode
>   , all, infer, latex, bird, jekyll,  haskell, markdown, tildefence, backtickfence
>   , Lang, setLang
>   , Error(..), showError
> ) where

> import Data.Bool (bool)
> import Data.Foldable (asum)
> import Data.Functor ((<$>))
> import Data.Maybe (fromMaybe, maybeToList)
> import Data.Monoid ((<>))
> import Data.Text (Text, stripStart, stripEnd, stripPrefix, stripSuffix, isPrefixOf,
>                   unlines, lines, pack, drop, toLower)
> import Prelude hiding (all, or, String, unlines, lines, drop)

What are literate programs?
===========================

There are several styles of literate programming. Most commonly,
these are LaTeX-style code tags, Bird tags and Markdown fenced code
blocks.

> data Delimiter
>   = LaTeX    BeginEnd
>   | OrgMode  BeginEnd Lang
>   | Bird
>   | Jekyll   BeginEnd Lang
>   | Markdown Fence    Lang
>   | Asciidoc BeginEnd Lang
>   deriving (Eq, Show)

Some of these code blocks need to carry around additional information.
For instance, LaTex code blocks use distinct opening and closing tags.

> data BeginEnd
>   = Begin
>   | End
>   deriving (Eq, Show)

> isBegin :: Delimiter -> Bool
> isBegin (LaTeX    Begin  ) = True
> isBegin (OrgMode  Begin _) = True
> isBegin (Jekyll   Begin _) = True
> isBegin (Asciidoc Begin _) = True
> isBegin (Markdown _ _)     = True
> isBegin  _                 = False

> setBegin :: BeginEnd -> Delimiter -> Delimiter
> setBegin beginEnd (LaTeX    _  )    = LaTeX    beginEnd
> setBegin beginEnd (OrgMode  _ lang) = OrgMode  beginEnd lang
> setBegin beginEnd (Jekyll   _ lang) = Jekyll   beginEnd lang
> setBegin beginEnd (Asciidoc _ lang) = Asciidoc beginEnd lang
> setBegin _         del              = del

On the other hand, Markdown-style fences occur in two different variants.

> data Fence
>   = Tilde
>   | Backtick
>   deriving (Eq, Show)

Furthermore they may be annotated with all sorts of information. Most prominently,
their programming language.

> type Lang = Maybe Text

> hasLang :: Text -> Lang -> Maybe Lang
> hasLang "" Nothing          = Just Nothing
> hasLang l  Nothing          = Just $ Just $ toLower l
> hasLang l  (Just l')
>   | toLower l' == toLower l = Just $ Just $ toLower l'
>   | otherwise               = Nothing

In order to emit these code blocks, we will define the
following function.

> emitDelimiter :: Delimiter -> Text
> emitDelimiter (LaTeX Begin)         = "\\begin{code}"
> emitDelimiter (LaTeX End)           = "\\end{code}"
> emitDelimiter (OrgMode Begin l)     = "#+BEGIN_SRC" <+> fromMaybe "" l
> emitDelimiter (OrgMode End _)       = "#+END_SRC"
> emitDelimiter  Bird                 = ">"
> emitDelimiter (Jekyll Begin l)      = "{% highlight" <+> fromMaybe "" l <+> "%}"
> emitDelimiter (Jekyll End   _)      = "{% endhighlight %}"
> emitDelimiter (Asciidoc Begin l)    = "[source" <> maybe "" (", "<>) l <> "]\n----"
> emitDelimiter (Asciidoc End   _)    = "----"
> emitDelimiter (Markdown Tilde l)    = "~~~" <+> fromMaybe "" l
> emitDelimiter (Markdown Backtick l) = "```" <+> fromMaybe "" l

> infixr 5 <+>
> (<+>) :: Text -> Text -> Text
> "" <+> y  = y
> x  <+> "" = x
> x  <+> y  = x <> " " <> y

Furthermore, we need a set of functions which is able to recognise
these code blocks.

> type Recogniser = Text -> Maybe Delimiter

For instance, in LaTeX-style, a codeblock is delimited by
`\begin{code}` and `\end{code}` tags, which must appear at the first
position (since we do not support indented code blocks).

> isLaTeX :: Recogniser
> isLaTeX l
>   | "\\begin{code}" `isPrefixOf` stripStart l = Just $ LaTeX Begin
>   | "\\end{code}"   `isPrefixOf` stripStart l = Just $ LaTeX End
>   | otherwise = Nothing

> isOrgMode :: Lang -> Recogniser
> isOrgMode lang l
>   | Just rest <- stripStart . stripEnd <$> stripPrefix "#+BEGIN_SRC" (stripStart l),
>     Just lang' <- rest `hasLang` lang       = Just $ OrgMode Begin lang'
>   | "#+END_SRC"   `isPrefixOf` stripStart l = Just $ OrgMode End Nothing
>   | otherwise = Nothing

In Bird-style, every line in a codeblock must start with a Bird tag.
A tagged line is defined as *either* a line containing solely the
symbol '>', or a line starting with the symbol '>' followed by at
least one space.

> isBird :: Recogniser
> isBird l = bool Nothing (Just Bird) (l == ">" || "> " `isPrefixOf` l)

Due to this definition, whenever we strip a bird tag, in normal
whitespace modes we also remove the first space following it.

> stripBird :: Text -> Text
> stripBird = stripBird' WsKeepIndent

> stripBird' :: WhitespaceMode -> Text -> Text
> stripBird' WsKeepAll    l = " " <> drop 1 l
> stripBird' WsKeepIndent l = drop 2 l

Then we have Jekyll Liquid code blocks.

> isJekyll :: Lang -> Recogniser
> isJekyll lang l
>   | Just rest <- stripStart <$> stripPrefix "{% highlight" (stripStart l),
>     Just rest' <- stripEnd <$> stripSuffix "%}" (stripEnd rest),
>     Just lang' <- rest' `hasLang` lang  = Just $ Jekyll Begin lang'
>   | "{% endhighlight %}" `isPrefixOf` l = Just $ Jekyll End   lang
>   | otherwise                           = Nothing

Markdown fenced codeblocks have as a peculiarity that they
can be defined to only match on fences for a certain language.

Below we only check if the given language occurs *anywhere* in the
string; we don't bother parsing the entire line to see if it's
well-formed Markdown.

> isMarkdown :: Fence -> Text -> Lang -> Recogniser
> isMarkdown fence fenceStr lang l
>   | Just rest <- stripStart . stripEnd <$> stripPrefix fenceStr l,
>     Just lang' <- rest `hasLang` lang = Just $ Markdown fence lang'
>   | otherwise                         = Nothing

The Asciidoc fence in the beginning takes two lines, `[source,lang]` and `----`.
Here we just check for the source line. The second line will be consumed by asciidocBlock.

> isAsciidoc :: Lang -> Recogniser
> isAsciidoc lang l
>   | Just rest <- stripStart <$> stripPrefix "[source," l,
>     Just rest' <- stripEnd <$> stripSuffix "]" (stripEnd rest),
>     Just lang' <- rest' `hasLang` lang = Just $ Asciidoc Begin lang'
>   | "----" `isPrefixOf` l              = Just $ Asciidoc End   lang
>   | otherwise                          = Nothing

> asciidocFence :: [(Int,Text)] -> Maybe [(Int,Text)]
> asciidocFence ls | ((_,"----"):ls') <- ls = Just ls'
>                  | otherwise              = Nothing

In general, we will also need a function that checks, for a given
line, whether it conforms to *any* of a set of given styles.

> isDelimiter :: Style -> Recogniser
> isDelimiter ds l = asum (map go ds)
>   where
>     go (LaTeX _)                = isLaTeX l
>     go  Bird                    = isBird l
>     go (Jekyll _ lang)          = isJekyll lang l
>     go (Markdown Tilde lang)    = isMarkdown Tilde "~~~" lang l
>     go (Markdown Backtick lang) = isMarkdown Backtick "```" lang l
>     go (OrgMode _ lang)         = isOrgMode lang l
>     go (Asciidoc _ lang)        = isAsciidoc lang l

And, for the styles which use opening and closing brackets, we will
need a function that checks if these pairs match.

> match :: Delimiter -> Delimiter -> Bool
> match (LaTeX Begin)      (LaTeX End)      = True
> match (Jekyll Begin _)   (Jekyll End _)   = True
> match (OrgMode Begin _)  (OrgMode End _)  = True
> match (Asciidoc Begin _) (Asciidoc End _) = True
> match (Markdown f _)     (Markdown g _)   = f == g
> match  _                  _               = False

Note that Bird-tags are notably absent from the `match` function, as
they are a special case.

What do we want `unlit` to do?
==============================

The `unlit` program that we will implement below will do the following:
it will read a literate program from the standard input—allowing one
or more styles of code block—and emit only the code to the standard
output.

The options for source styles are as follows:

> type Style = [Delimiter]

> all, backtickfence, tildefence, bird, haskell, infer,
>   jekyll, latex, markdown, orgmode, asciidoc :: Style
> all           = latex <> markdown <> orgmode <> jekyll <> asciidoc
> backtickfence = [Markdown Backtick Nothing]
> tildefence    = [Markdown Tilde Nothing]
> bird          = [Bird]
> haskell       = latex <> bird
> infer         = []
> jekyll        = [Jekyll Begin Nothing, Jekyll End Nothing]
> latex         = [LaTeX Begin, LaTeX End]
> markdown      = bird <> tildefence <> backtickfence
> orgmode       = [OrgMode Begin Nothing, OrgMode End Nothing]
> asciidoc      = [Asciidoc Begin Nothing, Asciidoc End Nothing]

> parseStyle :: Text -> Maybe Style
> parseStyle s = case toLower s of
>   "all"           -> Just all
>   "backtickfence" -> Just backtickfence
>   "bird"          -> Just bird
>   "haskell"       -> Just haskell
>   "infer"         -> Just infer
>   "jekyll"        -> Just jekyll
>   "latex"         -> Just latex
>   "markdown"      -> Just markdown
>   "orgmode"       -> Just orgmode
>   "asciidoc"      -> Just asciidoc
>   "tildefence"    -> Just tildefence
>   _               -> Nothing

It is possible to set the language of the source styles using the following function.

> setLang :: Lang -> Style -> Style
> setLang = fmap . setDelimLang

> setDelimLang :: Lang -> Delimiter -> Delimiter
> setDelimLang lang (Markdown fence _)   = Markdown fence lang
> setDelimLang lang (Asciidoc fence _)   = Asciidoc fence lang
> setDelimLang lang (OrgMode beginEnd _) = OrgMode beginEnd lang
> setDelimLang lang (Jekyll beginEnd _)  = Jekyll beginEnd lang
> setDelimLang _     d                   = d

> getDelimLang :: Delimiter -> Lang
> getDelimLang (Markdown _ lang) = lang
> getDelimLang (OrgMode  _ lang) = lang
> getDelimLang (Jekyll   _ lang) = lang
> getDelimLang (Asciidoc _ lang) = lang
> getDelimLang _                 = Nothing

Additionally, when the source style is empty, the program will
attempt to guess the style based on the first delimiter it
encounters. It will try to be permissive in this, and therefore, if
it encounters a Bird-tag, will infer general Markdown-style.

> inferred :: Maybe Delimiter -> Style
> inferred  Nothing              = []
> inferred (Just (LaTeX _))      = latex
> inferred (Just (Jekyll _ _))   = jekyll
> inferred (Just (OrgMode _ _))  = orgmode
> inferred (Just (Asciidoc _ _)) = asciidoc
> inferred (Just _)              = markdown

Lastly, we would like `unlit` to be able to operate in several
different whitespace modes. For now, these are:

> data WhitespaceMode
>   = WsKeepIndent -- ^ keeps only indentations
>   | WsKeepAll    -- ^ keeps all lines and whitespace

> parseWhitespaceMode :: Text -> Maybe WhitespaceMode
> parseWhitespaceMode s = case toLower s of
>   "all"    -> Just WsKeepAll
>   "indent" -> Just WsKeepIndent
>   _        -> Nothing

We would like to combine the inferred style with current styles as
one would combine maybe values using the alternative operator
`(<|>)`. Therefore, we will define our own version of this operator.

> or :: [a] -> [a] -> [a]
> xs `or` [] = xs
> [] `or` ys = ys
> xs `or` _  = xs

Thus, the `unlit` function will have two parameters: its source style
and the text to convert.

> unlit :: WhitespaceMode -> Style -> Text -> Either Error Text
> unlit ws ss = fmap unlines . unlit' ws ss Nothing . zip [1..] . lines

However, the helper function `unlit'` is best thought of as a finite
state automaton, where the states are used to remember the what kind
of code block (if any) the automaton currently is in.

> type State = Maybe Delimiter

With this, the signature of `unlit'` becomes:

> unlit' :: WhitespaceMode -> Style -> State -> [(Int, Text)] -> Either Error [Text]
> unlit' _ _  Nothing    []  = Right []
> unlit' _ _ (Just Bird) []  = Right []
> unlit' _ _ (Just o)    []  = Left $ UnexpectedEnd o
> unlit' ws ss q ((n, l):ls) = case (q, q') of

>   (Nothing  , Nothing)   -> continue  lineIfKeepAll

>   (Just Bird, Nothing)   -> close     lineIfKeepAll
>   (Just _o  , Nothing)   -> continue  [l]

>   (Nothing  , Just Bird) -> open      $ lineIfKeepIndent <> [stripBird' ws l]
>   (Nothing  , Just (Asciidoc Begin _))
>     | Just ls' <- asciidocFence ls
>                          -> open' ls' $ lineIfKeepAll <> lineIfKeepIndent
>   (Nothing  , Just c)
>     | isBegin c          -> open      $ lineIfKeepAll <> lineIfKeepIndent
>     | otherwise          -> continue  lineIfKeepAll

>   (Just Bird, Just Bird) -> continue  [stripBird' ws l]
>   (Just _o  , Just Bird) -> continue  [l]
>   (Just o   , Just c)
>     | o `match` c        -> close     lineIfKeepAll
>     | otherwise          -> Left      $ SpuriousBeginDelimiter n c

>   where
>     q'                    = isDelimiter (maybe id (const $ setLang Nothing) q (ss `or` all)) l
>     continueWith r ls' l' = (l' <>) <$> unlit' ws (ss `or` inferred q') r ls'
>     open'                 = continueWith q'
>     open                  = open' ls
>     continue              = continueWith q ls
>     close                 = continueWith Nothing ls
>     lineIfKeepAll         = case ws of WsKeepAll    -> [""]; WsKeepIndent -> []
>     lineIfKeepIndent      = case ws of WsKeepIndent -> [""]; WsKeepAll -> []

What do we want `relit` to do?
==============================

Sadly, no, `relit` won't be able to take source code and
automatically convert it to literate code. I'm not quite up to the
challenge of automatically generating meaningful documentation from
arbitrary code... I wish I was.

What `relit` will do is read a literate file using one style of
delimiters and emit the same file using an other style of delimiters.

> relit :: Style -> Delimiter -> Text -> Either Error Text
> relit ss ts = fmap unlines . relit' ss ts Nothing . zip [1..] . lines

Again, we will interpret the helper function `relit'` as an
automaton, which remembers the current state. However, we now also
need a function which can emit code blocks in a certain style. For
this purpose we will define a few functions.

TODO: Currently, if a delimiter is indented, running `relit` will remove this
      indentation. This is obviously an error, however changing it would require
      adding indentation information to all delimiters.

> emitBird :: Text -> Text
> emitBird l | stripStart l == "" = ">"
>            | otherwise          = "> " <> l

> emitOpen :: Delimiter -> Maybe Text -> [Text]
> emitOpen  Bird l = fmap emitBird (maybeToList l)
> emitOpen  del  l = emitDelimiter (setBegin Begin del) : maybeToList l

> emitCode :: Delimiter -> Text -> Text
> emitCode Bird l = emitBird l
> emitCode _    l = l

> emitClose :: Delimiter -> Maybe Text -> [Text]
> emitClose  Bird l = maybeToList l
> emitClose  del  l = emitDelimiter (setBegin End $ setDelimLang Nothing del) : maybeToList l

Using these simple functions we can easily define the `relit'`
function.

> relit' :: Style -> Delimiter -> State -> [(Int, Text)] -> Either Error [Text]
> relit' _ _   Nothing    [] = Right []
> relit' _ ts (Just Bird) [] = Right (emitClose ts Nothing)
> relit' _ _  (Just o)    [] = Left $ UnexpectedEnd o
> relit' ss ts q ((n, l):ls) = case (q, q') of

>   (Nothing  , Nothing)   -> continue

>   (Nothing  , Just Bird) -> blockOpen $ Just (stripBird l)
>   (Nothing  , Just (Asciidoc Begin _))
>     | Just ls' <- asciidocFence ls
>                          -> blockOpen' ls' Nothing
>   (Nothing  , Just c)
>     | isBegin c          -> blockOpen Nothing
>     | otherwise          -> continue

>   (Just Bird, Nothing)   -> blockClose $ Just l
>   (Just _o  , Nothing)   -> blockContinue l

>   (Just Bird, Just Bird) -> blockContinue $ stripBird l
>   (Just _o  , Just Bird) -> continue
>   (Just o   , Just c)
>     | o `match` c        -> blockClose Nothing
>     | otherwise          -> Left $ SpuriousBeginDelimiter n c

>   where
>     q'                = isDelimiter (maybe id (const $ setLang Nothing) q (ss `or` all)) l
>     ts'               = case q' >>= getDelimLang of Nothing -> ts; x@Just{} -> setDelimLang x ts
>     continueWith      = relit' (ss `or` inferred q') ts
>     continue          = (l :)                 <$> continueWith q ls
>     blockOpen' ls' l' = (emitOpen  ts' l' <>) <$> continueWith q' ls'
>     blockOpen         = blockOpen' ls
>     blockContinue  l' = (emitCode  ts l' :)   <$> continueWith q ls
>     blockClose     l' = (emitClose ts l' <>)  <$> continueWith Nothing ls

Error handling
==============

In case of an error both `unlit` and `relit` return a value of the datatype `Error`.

> data Error
>   = SpuriousBeginDelimiter Int Delimiter
>   | SpuriousEndDelimiter   Int Delimiter
>   | UnexpectedEnd              Delimiter
>   deriving (Eq, Show)

We can get a text representation of the error using `showError`.

> showError :: Error -> Text
> showError (UnexpectedEnd            q) = "unexpected end of file: unmatched " <> emitDelimiter q
> showError (SpuriousBeginDelimiter n q) = "at line " <> pack (show n) <> ": spurious begin "  <> emitDelimiter q
> showError (SpuriousEndDelimiter   n q) = "at line " <> pack (show n) <> ": spurious end "  <> emitDelimiter q
