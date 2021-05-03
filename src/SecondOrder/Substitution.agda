-- {-# OPTIONS --allow-unsolved-metas #-}

open import Agda.Primitive using (lzero; lsuc; _⊔_; Level)
open import Relation.Unary hiding (_∈_)
open import Data.Empty.Polymorphic
open import Data.List
open import Function.Base
open import Relation.Binary using (Setoid)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; subst)
open import SecondOrder.Arity

import SecondOrder.SecondOrderSignature as SecondOrderSignature

module SecondOrder.Substitution {ℓs ℓo ℓa : Level} {𝔸 : Arity} {Σ : SecondOrderSignature.Signature {ℓs} {ℓo} {ℓa} 𝔸}where

  open SecondOrderSignature {ℓs} {ℓo} {ℓa}
  open Signature 𝔸 Σ

  module _ {Θ : MetaContext}  where
      infix 4 _⇒r_

    -- ** Renamings **

      -- a renaming is a morphism between scopes
      -- renaming
      _⇒r_ : ∀ (Γ Δ : Context) → Set ℓs
      Γ ⇒r Δ = ∀ {A} → A ∈ Γ → A ∈ Δ

      -- extending a renaming
      extend-r : ∀ {Γ Δ} → Γ ⇒r Δ → ∀ {Ξ} → Γ ,, Ξ ⇒r Δ ,, Ξ
      extend-r ρ (var-inl x) = var-inl (ρ x)
      extend-r ρ (var-inr y) = var-inr y

      -- the identity renaming
      id-r : ∀ {Γ : Context} → Γ ⇒r Γ
      id-r x = x

      -- composition of renamings
      _∘r_ : ∀ {Γ Δ Θ : Context} → Δ ⇒r Θ → Γ ⇒r Δ → Γ ⇒r Θ
      (σ ∘r ρ) x = σ (ρ x)

      infix 7 _∘r_

      -- action of a renaming on terms
      tm-rename : ∀ {Γ Δ A} → Γ ⇒r Δ → Term Θ Γ A → Term Θ Δ A
      tm-rename ρ (tm-var x) = tm-var (ρ x)
      tm-rename ρ (tm-meta M ts) = tm-meta M (λ i → tm-rename ρ (ts i))
      tm-rename ρ (tm-oper f es) = tm-oper f (λ i → tm-rename (extend-r ρ) (es i))

      syntax tm-rename ρ t = t [ ρ ]r

      infix 6 tm-rename

      -- the reassociation renaming
      rename-assoc-r : ∀ {Γ Δ Ξ} → (Γ ,, Δ) ,, Ξ ⇒r Γ ,, (Δ ,, Ξ)
      rename-assoc-r (var-inl (var-inl x)) = var-inl x
      rename-assoc-r (var-inl (var-inr y)) = var-inr (var-inl y)
      rename-assoc-r (var-inr z) = var-inr (var-inr z)

      rename-assoc-l : ∀ {Γ Δ Ξ} → Γ ,, (Δ ,, Ξ) ⇒r (Γ ,, Δ) ,, Ξ
      rename-assoc-l (var-inl x) = var-inl (var-inl x)
      rename-assoc-l (var-inr (var-inl y)) = var-inl (var-inr y)
      rename-assoc-l (var-inr (var-inr z)) = var-inr z

      -- apply the reassociation renaming on terms
      term-reassoc : ∀ {Δ Γ Ξ A}
        → Term Θ (ctx-concat Δ (ctx-concat Γ Ξ)) A
        → Term Θ (ctx-concat (ctx-concat Δ Γ) Ξ) A
      term-reassoc = tm-rename rename-assoc-l

      -- the empty context is the unit
      rename-ctx-empty-r : ∀ {Γ} → Γ ,, ctx-empty ⇒r Γ
      rename-ctx-empty-r (var-inl x) = x

      -- weakening
      weakenˡ : ∀ {Γ Δ A} → Term Θ Γ A → Term Θ (Γ ,, Δ) A
      weakenˡ = tm-rename var-inl

      weakenʳ : ∀ {Γ Δ A} → Term Θ Δ A → Term Θ (Γ ,, Δ) A
      weakenʳ = tm-rename var-inr

      -- this is probably useless to have a name for
      -- but it allows us to use the extended renaming as a fuction from terms to terms
      app-extend-r : ∀ {Γ Δ Ξ A} → Γ ⇒r Δ → Term Θ (Γ ,, Ξ) A → Term Θ (Δ ,, Ξ) A
      app-extend-r ρ t = t [ extend-r ρ ]r

    -- ** Substitutions **

      -- substitition
      _⇒s_ : ∀ (Γ Δ : Context) → Set (lsuc (ℓs ⊔ ℓo ⊔ ℓa))
      Γ ⇒s Δ = ∀ {A} (x : A ∈ Δ) → Term Θ Γ A

      infix 4 _⇒s_

      -- extending a substitution
      extend-sˡ : ∀ {Γ Δ Ξ} → Γ ⇒s Δ → Γ ,, Ξ ⇒s Δ ,, Ξ
      extend-sˡ {Ξ = Ξ} σ (var-inl x) = weakenˡ (σ x)
      extend-sˡ σ (var-inr x) = tm-var (var-inr x)

      extend-sʳ : ∀ {Γ Δ Ξ} → Γ ⇒s Δ → Ξ ,, Γ ⇒s Ξ ,, Δ
      extend-sʳ {Ξ = Ξ} σ (var-inl x) = tm-var (var-inl x)
      extend-sʳ σ (var-inr x) = weakenʳ (σ x)

      -- the action of a substitution on a term (contravariant)
      _[_]s : ∀ {Γ Δ : Context} {A : sort} → Term Θ Δ A → Γ ⇒s Δ → Term Θ Γ A
      (tm-var x) [ σ ]s = σ x
      (tm-meta M ts) [ σ ]s = tm-meta M (λ i → (ts i) [ σ ]s)
      (tm-oper f es) [ σ ]s = tm-oper f (λ i → es i [ extend-sˡ σ ]s)

      infixr 6 _[_]s

      -- identity substitution
      id-s : ∀ {Γ : Context} → Γ ⇒s Γ
      id-s = tm-var

      -- application of extension
      -- this is probably useless to have a name for, but it does give a way to make a
      -- function to go from Terms to Terms
      app-extend-sˡ : ∀ {Γ Δ Ξ A} → Γ ⇒s Δ → Term Θ (Δ ,, Ξ) A → Term Θ (Γ ,, Ξ) A
      app-extend-sˡ σ t = t [ extend-sˡ σ ]s

      -- composition of substitutions
      _∘s_ : ∀ {Γ Δ Θ : Context} → Δ ⇒s Θ → Γ ⇒s Δ → Γ ⇒s Θ
      (σ ∘s ρ) x = σ x [ ρ ]s

      infixl 7 _∘s_

      -- action of a renaming on a substitution
      _r∘s_ : ∀ {Γ Δ Ξ} → Γ ⇒r Δ → Ξ ⇒s Δ → Ξ ⇒s Γ
      (ρ r∘s σ) x = σ (ρ x)
    
      -- action of a substitution on a renaming
      _s∘r_ : ∀ {Γ Δ Ξ} → Δ ⇒s Γ → Δ ⇒r Ξ → Ξ ⇒s Γ
      (σ s∘r ρ) x = (σ x) [ ρ ]r

  -- ** Metavariable instantiations **

  -- metavariable instantiation
  mv-inst  : MetaContext → MetaContext → Context → Set (lsuc (ℓs ⊔ ℓo ⊔ ℓa))
  mv-inst Θ Ψ Γ = ∀ (M : mv Θ) → Term Ψ (Γ ,, mv-arity Θ M) (mv-sort Θ M)

  syntax mv-inst Θ ψ Γ = ψ ⇒M Θ ⊕ Γ


  -- action of a metavariable instantiation on terms
  _[_]M : ∀ {Γ : Context} {A : sort} {Θ Ψ : MetaContext} {Δ} → Term Θ Γ A → ∀ (ι : mv-inst Θ Ψ Δ) → Term Ψ (Δ ,, Γ) A

  []M-mv : ∀ {Γ : Context} {Θ Ψ : MetaContext} {Δ} (M : mv Θ) (ts : ∀ {B} (i : mv-arg Θ M B) → Term Θ Γ B) (ι : mv-inst Θ Ψ Δ) → Δ ,, Γ ⇒s Δ ,, mv-arity Θ M

  []M-mv M ts ι (var-inl x) = tm-var (var-inl x)
  []M-mv M ts ι (var-inr x) =  (ts x) [ ι ]M

  (tm-var x) [ ι ]M = tm-var (var-inr x)
  _[_]M {Γ = Γ} {Θ = Θ} {Δ = Δ} (tm-meta M ts) ι = (ι M) [ []M-mv M ts ι ]s
  _[_]M {Ψ = Ψ} (tm-oper f es) ι = tm-oper f (λ i → tm-rename (rename-assoc-l {Θ = Ψ}) (es i [ ι ]M) )

  infixr 6 _[_]M

  -- the identity metavariable instantiation
  id-M : ∀ {Θ} → mv-inst Θ Θ ctx-empty
  id-M t = tm-meta t (λ i → weakenʳ (tm-var i))

  -- composition of metavariable instantiations
  _∘M_ : ∀ {Θ ψ Ω Γ Δ} → Ω ⇒M ψ ⊕ Δ → ψ ⇒M Θ ⊕ Γ → (Ω ⇒M Θ ⊕ (Δ ,, Γ))
  _∘M_ {Θ = Θ} {ψ = ψ} {Γ = Γ} {Δ = Δ} μ ι = λ M → term-reassoc (ι M [ μ ]M)


-- ** Interactions **

  -- action of a metavariable instantiation on a substitution
  _M∘s_ : ∀ {Θ ψ Γ Δ Ξ} → ψ ⇒M Θ ⊕ Ξ → _⇒s_ {Θ = Θ} Δ Γ → _⇒s_ {Θ = ψ} (Ξ ,, Δ) (Ξ ,, Γ)
  (ι M∘s σ) (var-inl x) = tm-var (var-inl x)
  (ι M∘s σ) (var-inr x) = σ x [ ι ]M

  -- action of a substitution on a metavariable instantiation
  _s∘M_ : ∀ {Θ ψ Γ Δ} → _⇒s_ {Θ = ψ} Δ Γ → ψ ⇒M Θ ⊕ Γ → ψ ⇒M Θ ⊕ Δ
  _s∘M_ σ ι M = ι M [ extend-sˡ σ ]s

  -- action of a renaming on a metavariable instantiation
  _r∘M_ : ∀ {Θ ψ Δ Ξ} → ψ ⇒M Θ ⊕ Ξ → _⇒r_ {Θ = Θ} Ξ Δ → ψ ⇒M Θ ⊕ Δ
  _r∘M_ {Θ = Θ} ι ρ M = tm-rename (extend-r {Θ = Θ} ρ) (ι M)

