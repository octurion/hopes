--  Copyright (C) 2006-2008 Angelos Charalambidis <a.charalambidis@di.uoa.gr>
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2, or (at your option)
--  any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; see the file COPYING.  If not, write to
--  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
--  Boston, MA 02110-1301, USA.

{-# OPTIONS -fglasgow-exts #-}
module Pretty (
        module Pretty,
        module Text.PrettyPrint
    ) where

import Text.PrettyPrint

import Loc
import Lang
import Syntax
import Types
import List (nub)
import Hopl
import qualified KnowledgeBase as KB

class Pretty a where
    ppr :: a -> Doc

pprint a = print (ppr a)

instance Pretty Doc where
    ppr = id

instance Pretty [Char] where
    ppr = text

instance Pretty Int where
    ppr = int

dcolon  = text "::"
arrow   = text "->"
dot     = char '.'
entails = text ":-"
-- semi = text ";"
curly a = text "{" <+> a <+> text "}"

instance Pretty Loc where
    ppr (Loc _ (-1) (-1)) = text "<no-location>"
    ppr (Loc f l c) = hcat $ punctuate colon [ text f, int l, int c ]

instance Pretty LocSpan where
    ppr (OneLineSpan f l c1 c2) =
        hcat $ punctuate colon [ text f, int l, parens $ int c1 <> char '-' <> int c2 ]
    ppr (MultiLineSpan f l1 c1 l2 c2) = 
        hcat $ punctuate colon [ text f, ppr_par l1 c1 <> char '-' <> ppr_par l2 c2 ]
        where ppr_par l c = parens (int l <> comma <> int c)
    ppr (LocSpan l1 l2) = ppr l1 <> char '-' <> ppr l2

instance Pretty Sym where
    ppr (Sym s) = ppr s
    ppr AnonSym = text "_"

instance Pretty a => Pretty (Typed a) where
    ppr (T a ty) = ppr a -- <> dcolon <> ppr ty

instance Pretty GrdType where
    ppr TyBool = text "o"
    ppr TyAll  = text "i"

instance Pretty TyVar where
    ppr (Tv i _) = int i

instance (Eq a, Pretty a) => Pretty (MonoTypeV a) where
    ppr t = pprPrec 1 f t
        where f = tvmap [t]

-- pprPrec p f (TyTup tl)     = parens $ sep (punctuate comma (map (pprPrec 1 f) tl))
pprPrec p f (TyGrd c)      = ppr c
pprPrec p f (TyVar v)      = f v
pprPrec p f ty@(TyFun t t') =  if (p == 0) then
                                   parens (sep [ pprPrec 0 f t , arrow <+> pprPrec p f t' ])
                               else
                                   sep [ pprPrec 0 f t , arrow <+> pprPrec p f t' ]

tynames = letters ++ [ x++(show i) | x <- letters, i <- [1..] ]
    where letters = [ "a", "b", "c", "d", "e", "f" ]

tvmap tys v = 
    let tvs = nub $ concatMap tyvars tys
        fl  = zip tvs tynames
    in case lookup v fl of
            Nothing -> ppr v
            Just n  -> text n


instance Pretty a => Pretty (TySig a) where
    ppr (a,t) = sep [ ppr a, dcolon <+> ppr t]

instance Pretty a => Pretty (TyEnv a) where
    ppr ts = vcat $ map ppr ts

-- syntax

instance Pretty a => Pretty (HpExpr a) where
    ppr (HpAnn e ty)  = hsep [ ppr (unLoc e), dcolon, ppr ty ]
    ppr (HpPar e)     = parens (ppr (unLoc e))
    ppr (HpSym s)     = ppr s
    ppr (HpApp e es)  = ppr (unLoc e) <>
                            parens (sep (punctuate comma (map (ppr.unLoc) es)))
    ppr (HpTup es)    = parens (sep (punctuate comma (map (ppr.unLoc) es)))
    ppr (HpLam xs e)  =
        sep (punctuate (text "->") (map (\x -> text "\\" <> ppr (symbolBind x)) xs)) <>
            text "->" <+> ppr (unLoc e)

instance Pretty a => Pretty (HpClause a) where
    ppr (HpClause _ [h] []) = ppr (unLoc h) <> dot
    ppr (HpClause _ h b)  =
        hang (  sep (punctuate comma (map (ppr.unLoc)  h)) <> entails) 4 $ 
                sep (punctuate comma (map (ppr.unLoc)  b)) <> dot


instance Pretty a => Pretty (HpSrc a) where
    ppr p = vcat $ map (ppr.unLoc) (clauses p)

instance (Pretty a, Eq a, Symbol a, HasConstants (Expr a), HasSignature (Expr a) a) => Pretty (Expr a) where
    ppr a =  pprPrec1 v' 1 a
        where {- v x = case lookup x vlist of
                      Nothing -> ppr x
                      Just n  -> text n
              vlist = zip (vars a) varnames
              letters = [ "X", "Y", "Z", "A", "B", "C", "D", "E", "F", "H", "K", "L" ]
              varnames = letters ++ [ x ++ (show i) | x <- letters, i <- [1..]] -}
              v' x = ppr x


pprPrec1 f p (Flex sym)    = (f sym)
pprPrec1 f p (Rigid sym)   = ppr sym
pprPrec1 f p e@(App e1 e2) =
    let fu = functor e
    in if (fu == ceq) then
            (sep (punctuate (text "=") (map (pprPrec1 f  p) $ args e)))
       else if fu == cand then
            (sep (punctuate comma (map (pprPrec1 f p) $ args e)))
       else if fu == cor then
            (sep (punctuate semi (map (pprPrec1 f p) $ args e)))
       else
            (pprPrec1 f p (functor e)) <> parens (sep (punctuate comma (map (pprPrec1 f p) $ args e)))

pprPrec1 f p (Lambda a e) =
    text "\\" <> (f a) <> text "." <+> (pprPrec1 f p e)

instance (Pretty a, Eq a, Symbol a,  HasConstants (Expr a), HasSignature (Expr a) a) => Pretty (Clause a) where
    ppr (C h b) = hang ((ppr h) <+> text "<:=") 4 $ ppr b

instance (Pretty a, Eq a, Symbol a,  HasConstants (Expr a), HasSignature (Expr a) a) => Pretty (KB.KnowledgeBase a) where
    ppr a = vcat $ map ppr (KB.clauses a)


{-
instance Pretty a => Pretty (Expr a) where
    ppr (Flex  sym)        = ppr sym
    ppr (Rigid sym)        = ppr sym
    ppr (Set es vs)        = curly  $ sep $ (punctuate comma (map ppr es)) ++ map (\v -> text "|" <+> ppr v) vs
    ppr (Tup es)           = parens $ sep $ (punctuate comma (map ppr es))
    ppr (App e e'@(Tup _)) = ppr e <> ppr e'
    ppr (App e e')         = ppr e <> parens (ppr e')

instance Pretty a => Pretty (Clause a) where
    ppr (h,b) = hang (sep [ppr h, entails]) 4 (sep (punctuate comma (map ppr  b)))

instance Pretty a => Pretty (Goal a) where
    ppr g = text "-?" <+> sep (punctuate comma (map ppr g))


instance Pretty a => Pretty (KB.KnowledgeBase a) where
    ppr p = vcat $ map ppr (KB.clauses p)
-}

