{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

module Cribbage (scoreSet, makeCard, scoreTheHand, shuffleNew, flipCutCard, newDeck, dealCards, dealFourCards, deal, dealTwoPlayers,
                Card(..)) where

import System.Random
import Data.List
--import Control.Monad
--import Control.Monad.Trans.Maybe
--import Control.Monad.Trans.Class
--import Control.Applicative
import GHC.Generics
import Data.Aeson
--import Data.Aeson.Casing
--import Data.Aeson.Parser
--import Data.Aeson.Encode.Pretty

data Suit = Clubs | Diamonds | Hearts | Spades
  deriving (Eq, Ord, Enum, Read, Generic, ToJSON, FromJSON)
instance Show Suit where
  show Hearts = "H" ; show Diamonds = "D" ; show Clubs  = "C" ; show Spades = "S"
--instance ToJSON Suit where
--  toJSON suit = object [ "Hearts" .= suit, "Diamonds" .= suit, "Clubs" .= suit, "Spades" .= suit]

data Rank = Ace | Two | Three | Four | Five | Six | Seven | Eight | Nine | Ten | Jack | Queen | King
  deriving (Eq, Ord, Enum, Read, Generic, ToJSON, FromJSON)
instance Show Rank where
   show Ace   = "A" ; show Two  = "2" ;  show Three  = "3" ; show Four  = "4"
   show Five  = "5" ; show Six  = "6" ;  show Seven  = "7" ; show Eight  = "8"
   show Nine  = "9" ; show Ten = "T" ; show Jack   = "J" ; show Queen   = "Q" ; show King   = "K"
--instance ToJSON Rank where
--  toJSON rank = object [ "A" .= rank, "2" .= rank, "3" .= rank, "4" .= rank, "5" .= rank, "6" .= rank,
--   "7" .= rank, "8" .= rank, "9" .= rank, "T" .= rank, "J" .= rank, "Q" .= rank, "K" .= rank]

data Card = Card { rank :: Rank, suit :: Suit }
  deriving (Eq, Ord, Generic, ToJSON, FromJSON)
instance Show Card where
  show (Card r s) = show r ++ show s
instance Read Card where
  readsPrec _ cs = [(Card r s, cs'')]
    where (r, cs') = head . reads $ cs
          (s, cs'') = head . reads $ cs'
--instance ToJSON Card where
--  toJSON card = object [
--    "rank" .= rank card,
--    "suit" .= suit card ]

data Player = Player { name :: String, score :: Int }
  deriving (Eq, Ord, Generic, ToJSON, FromJSON)

type Deck = [Card]
type Hand = [Card]
type CutCard = Card
-- pegging
type Pile = [Card]

cardValue :: Card -> Int
cardValue (Card Jack _) = 10
cardValue (Card Queen _) = 10
cardValue (Card King _) = 10
cardValue card = (fromEnum . rank $ card) + 1

-- pegging
countOfPile :: Pile -> Card -> Int
countOfPile cards card | (sum . map cardValue $ cards) + cardValue card <= 31 = (sum . map cardValue $ cards) + cardValue card
countOfPile cards _ = sum . map cardValue $ cards

scorePegging :: Int
scorePegging = 0

fifteen :: [Card] -> Int
fifteen cards | (sum . map cardValue $ cards) == 15 = 2
fifteen _ = 0

pair :: [Card] -> Int
pair [card1, card2] | rank card1 == rank card2 = 2
pair _ = 0

run :: [Card] -> Int
run cards | length cards >= 3 && run' (sort cards) = length cards
  where run' (c1:c2:cs) = rankValue c2 == rankValue c1 + 1 && run' (c2:cs)
        run' _ = True
        rankValue = fromEnum . rank
run _ = 0

flush :: [Card] -> Int
flush (topCard:remainingCards) | all (\x -> suit x == suitOfTopCard) remainingCards = length remainingCards + 1
  where suitOfTopCard = suit topCard
flush _ = 0

hisNobs :: Card -> Hand -> Int
hisNobs s = length . filter (\card -> suit card == suit s && rank card == Jack)

hisNibs :: Card -> Int
hisNibs (Card Jack _) = 2
hisNibs _ = 0

scoreTheHand :: Bool -> Card -> Hand -> Int
scoreTheHand isCrib theCutCard hand =
  (sum . map scoreSet . sets $ (theCutCard : hand))
    + runWrapper (theCutCard : hand)
    + hisNobs theCutCard hand
    + if fiveCardFlush then 5 else (if fourCardFlush && not isCrib then 4 else 0)
    where
      fiveCardFlush = flush (theCutCard:hand) == 5
      fourCardFlush = flush hand == 4

runWrapper :: [Card] -> Int
runWrapper cards
  | five > 0 = five
  | four > 0 = four
  | otherwise = three
  where
      five = sum . map run . (filter (\ n -> length n == 5) . sets) $ cards
      four = sum . map run . (filter (\ n -> length n == 4) . sets) $ cards
      three = sum . map run . (filter (\ n -> length n == 3) . sets) $ cards

listOfSize :: Int -> [[Card]] -> [[Card]]
listOfSize size = filter (\n -> length n == size)

pickRandomCard :: [a] -> IO a
pickRandomCard xs = (xs !!) <$> randomRIO (0, length xs - 1)

makeRandoms :: Int -> IO [Int]
makeRandoms = mapM (randomRIO . (,) 0) . enumFromTo 1 . pred

replaceAt :: Int -> a -> [a] -> [a]
replaceAt i c l =
 let (a, b) = splitAt i l
 in a ++ c : drop 1 b

swapElems :: (Int, Int) -> [a] -> [a]
swapElems (i, j) xs
 | i == j = xs
 | otherwise = replaceAt j (xs !! i) $ replaceAt i (xs !! j) xs

shuffleNew :: [a] -> IO [a]
shuffleNew xs = fmap (foldr swapElems xs . zip [1 ..]) (makeRandoms (length xs))

newDeck :: Deck
newDeck = [Card x y | y <- [Clubs .. Spades], x <- [Ace .. King]]

shuffle :: Deck -> IO Deck
shuffle deck =
    if not (null deck)
        then do
            let deckLength = length deck - 1
            n <- randomRIO(0, deckLength) :: IO Int
            let randomCard = deck !! fromIntegral n
            tailShuffle <- shuffle (delete randomCard deck)
            return (randomCard : tailShuffle)
        else return deck

makeCard :: String -> Card
makeCard = read

makeHand :: String -> Hand
makeHand = map read . words

showCard :: Card -> String
showCard (Card n s) = show n ++ " -- " ++ show s

randomCard :: IO ()
randomCard = randomRank >>= \rank -> randomSuit >>= \suit -> print (getCard rank suit)

randomRank :: IO Int
randomRank = randomRIO (0,12)

randomSuit :: IO Int
randomSuit = randomRIO (0,3)

getCard :: Int -> Int -> Card
getCard rank suit = Card ([Ace .. King] !! rank) ([Clubs .. Spades] !! suit)

createCard :: Rank ->  Suit -> Card
createCard = Card

fullDeck :: Deck
fullDeck = [ Card j i | i <- [Clubs .. Spades], j <- [Ace .. King] ]

deleteFromDeck :: Card -> Deck -> Deck
deleteFromDeck c = filter (== c)

addCard :: Card -> [Card] -> [Card]
addCard x xs = x:xs

dealCards :: Monad m => m Deck -> m Deck
dealCards d =
    do
    deck <- d
    return [deck !! n | n <- [0..51]]

dealFourCards :: Deck -> Hand
dealFourCards deck = sort([deck !! n | n <- [0..3]])

dealTwoPlayers :: Deck -> Int -> (Hand, Hand)
dealTwoPlayers deck x = ([deck !! n | n <- [0, 2..(2 * x-2)]], [deck !! n | n <- [1, 3..(2 * x-1)]])

flipCutCard :: Deck -> CutCard
flipCutCard = last

combination :: [Card] -> [[Card]]
combination [] = [[]]
combination (x:xs) = combination xs ++ map (x:) (combination xs)

sets :: [Card] -> [[Card]]
sets = tail . sort . combination

scoreSet :: [Card] -> Int
scoreSet cards = sum . map (\f -> f cards) $ [fifteen, pair]

-- Source: http://en.literateprograms.org/Fisher-Yates_shuffle_%28Haskell%29
shuffleDeck :: [a] -> IO [a]
shuffleDeck l = shuffleDeck' l []

shuffleDeck' :: [a] -> [a] -> IO [a]
shuffleDeck' [] acc = return acc
shuffleDeck' l acc =
  do k <- randomRIO (0, length l - 1)
     let (lead, x:xs) = splitAt k l
     shuffleDeck' (lead ++ xs) (x:acc)

-- Deal cards into piles of a specified size
deal :: [Card] -> [Int] -> [[Card]]
deal deck [] = [deck]
deal deck (pile:piles) = take pile deck:deal (drop pile deck) piles
