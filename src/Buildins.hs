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

module Buildins where

import Lang
import Types

mkBuildin "_" = AnonSym
mkBuildin s = liftSym s

isBuildin s = maybe False (const True) $ lookup s buildins'

buildinsigs = map (\(x,t) -> (liftSym x, t) ) buildins'

buildins' =
    [ (".",     TyFun tyAll (TyFun tyAll tyAll))
    , ("[]",    tyAll)
    , ("s",     TyFun tyAll tyAll)
    , ("true",  tyBool)
    , ("false", tyBool)
    , ("0",     tyAll)
    , ("=",     TyFun tyAll  (TyFun tyAll tyBool))
    , (",",     TyFun tyBool (TyFun tyBool tyBool))
    , (";",     TyFun tyBool (TyFun tyBool tyBool))
    , ("_",     tyAll)
    ]
