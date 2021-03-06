{-# LANGUAGE ConstraintKinds      #-}
{-# LANGUAGE DataKinds            #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE GADTs                #-}
{-# LANGUAGE KindSignatures       #-}
{-# LANGUAGE PolyKinds            #-}
{-# LANGUAGE QuasiQuotes          #-}
{-# LANGUAGE RankNTypes           #-}
{-# LANGUAGE RebindableSyntax     #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE TypeFamilies         #-}
{-# LANGUAGE TypeInType           #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE UndecidableInstances #-}
module Def where

import           Control.Monad.Free
import           Control.Monad.Indexed
import qualified Control.Monad.Indexed.Free    as F
import           Data.Kind
import           Data.Singletons
import           Data.Type.Natural              ( Nat )
import           Language.Poly.Core2             ( Core(..)
                                                , Serialise
                                                )
import           Prelude                 hiding ( return
                                                , (>>)
                                                , (>>=)
                                                )
import           Type

data ProcF (i :: SType * *) (j :: SType * *) next where
    Send :: (Serialise a) => Sing (n :: Nat) -> Core a -> next -> ProcF ('Free ('S n a j)) j next
    Recv :: (Serialise a) => Sing (n :: Nat) -> (Core a -> next) -> ProcF ('Free ('R n a j)) j next
    Branch :: (Serialise c) => Sing (n :: Nat) -> Proc' left ('Pure ()) c -> Proc' right ('Pure ()) c -> next -> ProcF ('Free ('B n left right j)) j next
    Select :: (Serialise a, Serialise b, Serialise c) => Sing (n :: Nat) -> Core (Either a b) -> (Core a -> Proc' left ('Pure ()) c) -> (Core b -> Proc' right ('Pure ()) c) -> next -> ProcF ('Free ('Se n left right j)) j next

type Proc' i j a = F.IxFree ProcF i j (Core a)
type Proc (i :: SType * *) a = forall j . F.IxFree ProcF (i >*> j) j (Core a)

instance Functor (ProcF i j) where
    fmap f (Send a v n                 ) = Send a v $ f n
    fmap f (Recv a cont                ) = Recv a (f . cont)
    fmap f (Branch r left right n      ) = Branch r left right $ f n
    fmap f (Select r v cont1 cont2 next) = Select r v cont1 cont2 (f next)

instance IxFunctor ProcF where
    imap = fmap

liftF' :: IxFunctor f => f i j a -> F.IxFree f i j a
liftF' = F.Free . imap F.Pure

send
    :: (Serialise a)
    => Sing n
    -> Core a
    -> Proc ( 'Free ( 'S n a ( 'Pure ()))) a
send role value = liftF' $ Send role value value

recv :: (Serialise a) => Sing n -> Proc ( 'Free ( 'R n a ( 'Pure ()))) a
recv role = liftF' (Recv role id)

select
    :: (Serialise a, Serialise b, Serialise c)
    => Sing n
    -> Core (Either a b)
    -> (Core a -> Proc' left ( 'Pure ()) c)
    -> (Core b -> Proc' right ( 'Pure ()) c)
    -> Proc ( 'Free ( 'Se n left right ( 'Pure ()))) ()
select role var cont1 cont2 = liftF' $ Select role var cont1 cont2 (Lit ())

branch
    :: (Serialise c)
    => Sing n
    -> Proc' left ( 'Pure ()) c
    -> Proc' right ( 'Pure ()) c
    -> Proc ( 'Free ( 'B n left right ( 'Pure ()))) ()
branch role one two = liftF' $ Branch role one two (Lit ())

(>>=) :: IxMonad m => m i j a -> (a -> m j k b) -> m i k b
(>>=) = (>>>=)

(>>) :: IxMonad m => m i j b -> m j k1 b1 -> m i k1 b1
a >> b = a >>= const b

return :: IxMonad m => a -> m i i a
return = ireturn

data Process (k :: (SType * *, Nat)) a where
    Process :: Sing (a :: Nat) -> Proc' info ('Pure ()) val -> Process '(info, a) val
    -- Process :: Sing (a :: Nat) -> Proc info val -> Process '(info, a) val

data PList (l::[*]) where
    PNil  :: PList '[]
    PCons :: Process k () -> PList l -> PList (Process k () ': l)

type family DualityCons procs :: Constraint where
    DualityCons xs = DualityC (ExtractInfo xs)

type family ExtractInfo procs :: [(SType * *, Nat)] where
    ExtractInfo '[] = '[]
    ExtractInfo (x ': xs) = ExtractProcessInfo x : ExtractInfo xs

type family ExtractProcessInfo (c :: *) :: (SType * *, Nat) where
    ExtractProcessInfo (Process k _) = k
