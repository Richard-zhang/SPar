{-# LANGUAGE ConstraintKinds        #-}
{-# LANGUAGE DataKinds              #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs                  #-}
{-# LANGUAGE KindSignatures         #-}
{-# LANGUAGE PolyKinds              #-}
{-# LANGUAGE RankNTypes             #-}
{-# LANGUAGE ScopedTypeVariables    #-}
{-# LANGUAGE TypeFamilies           #-}
{-# LANGUAGE TypeFamilyDependencies #-}
{-# LANGUAGE TypeInType             #-}
{-# LANGUAGE TypeOperators          #-}
{-# LANGUAGE UndecidableInstances   #-}
module Type where

import Control.Monad.Free
import Data.Functor.Classes
import Data.Kind
import Data.Singletons
import Data.Singletons.Decide
import Data.Singletons.TypeRepStar
import Data.Type.Natural (Nat)
import qualified GHC.TypeLits
import Type.Reflection

data STypeF a next where
    S :: Nat -> a -> next -> STypeF a next
    R :: Nat -> a -> next -> STypeF a next
    B :: Nat -> SType a c -> SType a c -> next -> STypeF a next
    Se :: Nat -> SType a c -> SType a c -> next -> STypeF a next
    -- Br :: [Nat] -> SType a c -> SType a c -> next -> STypeF a next
    Br :: [Nat] -> SType a c -> SType a c -> next -> STypeF a next

instance Functor (STypeF a) where
    fmap f (S r a n)    = S r a (f n)
    fmap f (R r a n)    = R r a (f n)
    fmap f (B r a b n)  = B r a b (f n)
    fmap f (Se r a b n) = B r a b (f n)
    -- fmap f (Br rs a b n) = Br rs a b (f n)
    fmap f (Br rs a b n) = Br rs a b (f n)

instance Eq a => Eq1 (STypeF a) where
    -- liftEq eq (S r v n) (S r' v' n')        = r == r' && v == v' && eq n n'
    -- liftEq eq (R r v n) (R r' v' n')        = r == r' && v == v' && eq n n'
    -- liftEq eq (S _ _ _) (R _ _ _)        = error "send recv doesn't match"
    -- liftEq eq (R _ _ _) (S _ _ _)        = error "recv send doesn't match"
    -- -- TODO potential issue => don't care the result type of SType since it's not part of the protocols
    -- liftEq eq (B r a b n) (B r' a' b' n')   = r == r' && liftEq (\_ _ -> True) a a' && eq n n'
    -- liftEq eq (Se r a b n) (Se r' a' b' n') = r == r' && liftEq (\_ _ -> True) a a' && eq n n'
    -- liftEq _ _ _ =undefined

instance Show a => Show1 (STypeF a) where
    -- liftShowsPrec sp _ d (S role v n) = showsUnaryWith sp (unwords ["S", show $ fromEnum role, show v]) d n
    -- liftShowsPrec sp _ d (R role v n) = showsUnaryWith sp (unwords ["R", show $ fromEnum role, show v]) d n
    -- liftShowsPrec sp _ d (B role a b n) = showsUnaryWith sp (unwords ["B", show $ fromEnum role, "l:", show (a >> Pure ()), "r:", show (b >> Pure ())]) d n
    -- liftShowsPrec sp _ d (Se role a b n) = showsUnaryWith sp (unwords ["Se", show $ fromEnum role, "l:", show (a >> Pure ()), "r:", show (b >> Pure ())]) d n
    -- liftShowsPrec sp _ d (Br roles a b n) = showsUnaryWith sp (unwords ["Br", show $ fmap fromEnum roles, "l:", show (a >> Pure ()), "r:", show (b >> Pure ())]) d n
    liftShowsPrec sp _ d (S role v n) = showsUnaryWith sp ("!<" ++ (show $ fromEnum role) ++ "," ++ show v ++ ">.") d n
    liftShowsPrec sp _ d (R role v n) = showsUnaryWith sp ("?<" ++ (show $ fromEnum role) ++ "," ++ show v ++ ">.") d n
    liftShowsPrec sp _ d (Se role a b n) = showsUnaryWith sp ("⊕<" ++ (show $ fromEnum role) ++ "," ++ "{" ++ "L: " ++ show (a >> Pure ()) ++ ", " ++ "R: " ++ show (b >> Pure ()) ++ "}>") d n
    liftShowsPrec sp _ d (B role a b n) = showsUnaryWith sp ("&<" ++ (show $ fromEnum role) ++ "," ++ "{" ++ "L: " ++ show (a >> Pure ()) ++ ", " ++ "R: " ++ show (b >> Pure ()) ++ "}>") d n
    liftShowsPrec sp _ d (Br role a b n) = showsUnaryWith sp ("Br<" ++ (show $ fmap fromEnum role) ++ "," ++ "{" ++ "L: " ++ show (a >> Pure ()) ++ ", " ++ "R: " ++ show (b >> Pure ()) ++ "}>") d n

type SType a next = Free (STypeF a) next

data instance Sing (t :: SType * *) where
    SPure :: Typeable (a :: *) => Proxy a -> Sing ('Pure a :: SType * *)
    SSend :: Typeable (a :: *) => Sing (r :: Nat) -> Proxy a -> Sing (n :: SType * *) -> Sing ('Free ('S r a n))
    SRecv :: Typeable (a :: *) => Sing (r :: Nat) -> Proxy a -> Sing (n :: SType * *) -> Sing ('Free ('R r a n))
    SBranch :: Sing (r :: Nat) -> Sing (left :: SType * *) -> Sing (right :: SType * *) -> Sing (n :: SType * *) -> Sing ('Free ('B r left right n))
    SSelect :: Sing (r :: Nat) -> Sing (left :: SType * *) -> Sing (right :: SType * *) -> Sing (n :: SType * *) -> Sing ('Free ('Se r left right n))

data SomeSType where
    SomeSType :: forall (n :: SType * *). Sing n -> SomeSType

instance SDecide (SType Type Type) where
    (SPure (a :: Proxy l)) %~ (SPure (b :: Proxy r)) = case (p2s a) %~ (p2s b) of
        Proved (Refl :: l :~: r) -> Proved (Refl :: 'Pure l :~: 'Pure r)
        Disproved _              -> Disproved undefined
    (SSend r1 v1 next1) %~ (SSend r2 v2 next2) = case
        (r1 %~ r2, (p2s v1) %~ (p2s v2), next1 %~ next2) of
        (Proved Refl, Proved Refl, Proved Refl) -> Proved Refl
        _                                       -> Disproved undefined
    _ %~ _ = Proved undefined

p2s :: Typeable (a :: *) => Proxy a -> Sing a
p2s = STypeRep . p2t where p2t (Proxy :: Proxy b) = typeRep :: TypeRep b

-- duality :: [(SomeSType, SomeSing Nat)] -> Bool 
-- duality procs = allProved $ fmap helper $ handShake procs
--     where
--         handShake []       = []
--         handShake (x : xs) = fmap ((,) x) xs ++ handShake xs
--         helper ((SomeSType a, SomeSing aid), (SomeSType b, SomeSing bid)) =
--             project a bid %~ project b aid
--         allProved [] = True
--         allProved (x : xs) = case x of
--             Proved Refl -> True
--             Disproved _ -> False

project :: Sing (a :: SType * *) -> Sing (r :: Nat) -> Sing (Project a r)  
project (SPure val) _ = SPure val
project (SSend role val next) n = case role %~ n of
    Proved Refl -> (SSend role val (project next n))
    Disproved _ -> undefined
    -- Disproved f -> project next n

dual :: Sing (a :: SType * *) -> Sing (r :: Nat) -> Sing (Dual a r :: SType * *)
dual = undefined

type family (>*>) (a :: SType * c) (b :: SType * c) where
    'Free ('S r v n) >*> b = 'Free ('S r v (n >*> b))
    'Free ('R r v n) >*> b = 'Free ('R r v (n >*> b))
    'Free ('B r n1 n2 n3) >*> b = 'Free ('B r n1 n2 (n3 >*> b))
    'Free ('Se r n1 n2 n3) >*> b = 'Free ('Se r n1 n2 (n3 >*> b))
    'Pure _ >*> b = b

type family Project (a :: SType * c) (r :: Nat) where
    Project ('Pure b) _ = ('Pure b)
    Project ('Free ('S r0 v next)) r0 = 'Free ('S r0 v (Project next r0))
    Project ('Free ('R r0 v next)) r0 = 'Free ('R r0 v (Project next r0))
    Project ('Free ('B r0 next1 next2 next)) r0 = 'Free ('B r0 (Project next1 r0) (Project next2 r0) (Project next r0))
    Project ('Free ('Se r0 next1 next2 next)) r0 = 'Free ('Se r0 (Project next1 r0) (Project next2 r0) (Project next r0))
    Project ('Free ('S r0 v next)) r1 = Project next r1
    Project ('Free ('R r0 v next)) r1 = Project next r1
    Project ('Free ('B r0 next1 next2 next)) r1 = ProjectHelper (Project next1 r1) (Project next2 r1) >*> Project next r1
    Project ('Free ('Se r0 next1 next2 next)) r1 = ProjectHelper (Project next1 r1) (Project next2 r1) >*> Project next r1

type family ProjectHelper (left :: SType * c) (right :: SType * c) :: SType * c where
    ProjectHelper a a = a
    ProjectHelper a b = GHC.TypeLits.TypeError ('GHC.TypeLits.Text "doesn't match in branches")

type family Dual (a :: SType * c) (r :: Nat) :: SType * c where
    Dual ('Pure b) _ = ('Pure b)
    Dual ('Free ('S r0 v next)) r1 = 'Free ('R r1 v (Dual next r1))
    Dual ('Free ('R r0 v next)) r1 = 'Free ('S r1 v (Dual next r1))
    Dual ('Free ('B r0 next1 next2 next)) r1 = 'Free ('Se r1 (Dual next1 r1) (Dual next2 r1) (Dual next r1))
    Dual ('Free ('Se r0 next1 next2 next)) r1 = 'Free ('B r1 (Dual next1 r1) (Dual next2 r1) (Dual next r1))

type family IsDualHelper (k1 :: (SType * c, Nat)) (k2 :: (SType * c, Nat)) :: Constraint where
    IsDualHelper '(a, aid) '(b, bid) = (Dual (Project a bid) aid ~ Project b aid, Dual (Project b aid) bid ~ Project a bid)

type family IsDual (k1 :: ((SType * c, Nat), (SType * c, Nat))) :: Constraint where
    IsDual '(k1, k2) = IsDualHelper k1 k2

type And (a :: Constraint) (b :: Constraint)  = (a, b)

type family AppendTop (a :: k1) (b :: [k2]) where
    AppendTop a '[] = '[]
    AppendTop a (x ': xs) = '(a, x) : AppendTop a xs

type family (++) (a :: [k]) (b :: [k]) where
    '[] ++ b = b
    (x ': xs) ++ b = x ': (xs ++ b)

type family Handshake (c :: [k]) where
    Handshake '[] = '[]
    Handshake (x ': xs) = AppendTop x xs ++ Handshake xs

type family DualityCHelper (c :: [((SType * b, Nat), (SType * b, Nat))]) :: Constraint where
    DualityCHelper '[] = 'Pure () ~ 'Pure ()
    DualityCHelper (x ': xs) = IsDual x `And` DualityCHelper xs

type family DualityC (c :: [(SType * b, Nat)]) :: Constraint where
    DualityC xs = DualityCHelper (Handshake xs)
