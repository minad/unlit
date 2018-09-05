LANG_STYLES=backtickfence tildefence orgmode jekyll asciidoc
NOLANG_STYLES=latex markdown

all: src/Unlit/String.hs README.md

test: test/ghcunlit
	make mixed_test
	runhaskell test/TestUnlit.hs
	make roundtrip

mixed_test:
	unlit -i test/mixed.md -o test/mixed_unlit.out || exit 1
	mv test/mixed_unlit.out test/mixed_unlit.expect || exit 1
	unlit -f markdown -l haskell -i test/mixed.md -o test/mixed_hs_unlit.out || exit 1
	mv test/mixed_hs_unlit.out test/mixed_hs_unlit.expect || exit 1
	@for i in $(LANG_STYLES); do \
		echo "mixed $$i"; \
		unlit -t $$i -i test/mixed.md -o test/mixed_$$i.out || exit 1; \
		mv test/mixed_$$i.out test/mixed_$$i.expect || exit 1; \
        done
	@for i in $(NOLANG_STYLES); do \
		echo "mixed $$i"; \
		unlit -t $$i -i test/mixed.md -o test/mixed_$$i.out || exit 1; \
		mv test/mixed_$$i.out test/mixed_$$i.expect || exit 1; \
        done

roundtrip:
	unlit -l haskell -i src/Unlit/Text.lhs -o test/roundtrip.unlit || exit 1
	@for i in $(LANG_STYLES); do \
		echo "$$i"; \
		unlit -t $$i -l haskell -i src/Unlit/Text.lhs -o test/roundtrip.1 || exit 1; \
		unlit -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 test/roundtrip.unlit || exit 1; \
		unlit -f $$i -t bird -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 src/Unlit/Text.lhs || exit 1; \
		for j in $(LANG_STYLES); do \
			echo " $$i <-> $$j"; \
			unlit -f $$i -t $$j -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
			unlit -f $$j -t $$i -i test/roundtrip.2 -o test/roundtrip.3 || exit 1; \
			diff test/roundtrip.1 test/roundtrip.3 || exit 1; \
		done; \
		echo "$$i inferred"; \
		unlit -t $$i -l haskell -i src/Unlit/Text.lhs -o test/roundtrip.1 || exit 1; \
		unlit -t bird -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 src/Unlit/Text.lhs || exit 1; \
		for j in $(LANG_STYLES); do \
			echo "  <-> $$j"; \
			unlit -t $$j -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
			unlit -t $$i -i test/roundtrip.2 -o test/roundtrip.3 || exit 1; \
			diff test/roundtrip.1 test/roundtrip.3 || exit 1; \
		done; \
		echo "$$i without empty lines"; \
		sed '/^\s*$$/d' src/Unlit/Text.lhs > test/roundtrip.0; \
		unlit -t $$i -l haskell -i test/roundtrip.0 -o test/roundtrip.1 || exit 1; \
		unlit -f $$i -t bird -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 test/roundtrip.0 || exit 1; \
		for j in $(LANG_STYLES); do \
			echo "  <-> $$j"; \
			unlit -f $$i -t $$j -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
			unlit -f $$j -t $$i -i test/roundtrip.2 -o test/roundtrip.3 || exit 1; \
			diff test/roundtrip.1 test/roundtrip.3 || exit 1; \
		done; \
		echo "$$i inferred without empty lines"; \
		sed '/^\s*$$/d' src/Unlit/Text.lhs > test/roundtrip.0; \
		unlit -t $$i -l haskell -i test/roundtrip.0 -o test/roundtrip.1 || exit 1; \
		unlit -t bird -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 test/roundtrip.0 || exit 1; \
		for j in $(LANG_STYLES); do \
			echo "  <-> $$j"; \
			unlit -t $$j -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
			unlit -t $$i -i test/roundtrip.2 -o test/roundtrip.3 || exit 1; \
			diff test/roundtrip.1 test/roundtrip.3 || exit 1; \
		done \
	done
	@for i in $(NOLANG_STYLES); do \
		echo "$$i"; \
		unlit -t $$i -l haskell -i src/Unlit/Text.lhs -o test/roundtrip.1 || exit 1; \
		unlit -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 test/roundtrip.unlit || exit 1; \
		unlit -f $$i -t bird -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 src/Unlit/Text.lhs || exit 1; \
		for j in $(NOLANG_STYLES); do \
			echo " $$i <-> $$j"; \
			unlit -f $$i -t $$j -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
			unlit -f $$j -t $$i -i test/roundtrip.2 -o test/roundtrip.3 || exit 1; \
			diff test/roundtrip.1 test/roundtrip.3 || exit 1; \
		done; \
		echo "$$i inferred"; \
		unlit -t $$i -l haskell -i src/Unlit/Text.lhs -o test/roundtrip.1 || exit 1; \
		unlit -t bird -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 src/Unlit/Text.lhs || exit 1; \
		for j in $(NOLANG_STYLES); do \
			echo "  <-> $$j"; \
			unlit -t $$j -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
			unlit -t $$i -i test/roundtrip.2 -o test/roundtrip.3 || exit 1; \
			diff test/roundtrip.1 test/roundtrip.3 || exit 1; \
		done; \
		echo "$$i without empty lines"; \
		sed '/^\s*$$/d' src/Unlit/Text.lhs > test/roundtrip.0; \
		unlit -t $$i -l haskell -i test/roundtrip.0 -o test/roundtrip.1 || exit 1; \
		unlit -f $$i -t bird -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 test/roundtrip.0 || exit 1; \
		for j in $(NOLANG_STYLES); do \
			echo "  <-> $$j"; \
			unlit -f $$i -t $$j -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
			unlit -f $$j -t $$i -i test/roundtrip.2 -o test/roundtrip.3 || exit 1; \
			diff test/roundtrip.1 test/roundtrip.3 || exit 1; \
		done; \
		echo "$$i inferred without empty lines"; \
		sed '/^\s*$$/d' src/Unlit/Text.lhs > test/roundtrip.0; \
		unlit -t $$i -l haskell -i test/roundtrip.0 -o test/roundtrip.1 || exit 1; \
		unlit -t bird -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
		diff test/roundtrip.2 test/roundtrip.0 || exit 1; \
		for j in $(NOLANG_STYLES); do \
			echo "  <-> $$j"; \
			unlit -t $$j -i test/roundtrip.1 -o test/roundtrip.2 || exit 1; \
			unlit -t $$i -i test/roundtrip.2 -o test/roundtrip.3 || exit 1; \
			diff test/roundtrip.1 test/roundtrip.3 || exit 1; \
		done \
	done

test/ghcunlit: test/ghcunlit.c
	gcc -O2 -o test/ghcunlit test/ghcunlit.c

dist: src/Main.hs src/Unlit/Text.lhs src/Unlit/String.hs
	cabal configure
	cabal sdist

build: src/Main.hs src/Unlit/Text.lhs src/Unlit/String.hs
	cabal configure
	cabal build

install: src/Main.hs src/Unlit/Text.lhs src/Unlit/String.hs
	cabal configure
	cabal install

README.md: Makefile src/Unlit/Text.lhs
	cat src/Unlit/Text.lhs \
	| unlit -t backtickfence -l haskell \
	| sed '1i [![Build Status](https://travis-ci.org/wenkokke/unlit.png?branch=master)](https://travis-ci.org/wenkokke/unlit)' \
	> README.md

src/Unlit/String.hs: Makefile src/Unlit/Text.lhs
	cat src/Unlit/Text.lhs                                                 \
	| unlit -f bird                                                        \
	| sed '1d;2d;17d;18d;19d'                                              \
	| sed 's/Text/String/g;s/pack//g'                                      \
	| sed '16i import Prelude hiding \(all, or\)'                          \
	| sed '17i import Data.List \(isPrefixOf, stripPrefix, dropWhileEnd\)' \
	| sed '18i import qualified Data.Char as Char\n'                       \
	| sed '20i stripStart, stripEnd, toLower :: String -> String'          \
	| sed '21i stripStart = dropWhile Char.isSpace'                        \
	| sed '22i stripEnd   = dropWhileEnd Char.isSpace'                     \
	| sed '23i toLower    = map Char.toLower'                              \
	| sed '24i stripSuffix :: Eq a => [a] -> [a] -> Maybe [a]'             \
	| sed '25i stripSuffix a b = reverse <$$> stripPrefix (reverse a) (reverse b)' \
	> src/Unlit/String.hs

.PHONY: test roundtrip dist build install
