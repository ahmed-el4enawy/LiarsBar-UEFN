# Liar's Bar (Liar's Deck) Game System for UEFN
# Main device and game logic for Liar's Bar

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

# Utility function for modulo operations that handles negative numbers correctly
ModOperation(Value : int, Modulus : int) : int =
    if (Modulus <= 0):
        return 0
    
    var Result : int = Value
    
    # Handle negative values
    loop:
        if (Result >= 0):
            break
        set Result = Result + Modulus
    
    # Perform modulo operation manually
    loop:
        if (Result < Modulus):
            break
        set Result = Result - Modulus
    
    return Result

# Utility function to get a random integer in range [Min, Max]  
RandomIntInRange(MinVal : int, MaxVal : int)<transacts>:int =
    if (MinVal > MaxVal):
        return MinVal  # Prevent invalid range
        
    RandGen := GetRandomNumberGenerator()
    Range := MaxVal - MinVal + 1
    RandomValue := RandGen.GetRandomInt(Range)
    return MinVal + RandomValue

# Card definitions
card_value_enum := enum{A, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, J, Q, K}

# Card object struct
card_struct := struct:
    Value : card_value_enum
    Suit : string  # "Hearts", "Diamonds", "Clubs", "Spades"

# Function to convert card value to string
CardValueToString(CardVal : card_value_enum) : string =
    if (CardVal = card_value_enum.A):
        return "Ace"
    else if (CardVal = card_value_enum.TWO):
        return "Two"
    else if (CardVal = card_value_enum.THREE):
        return "Three"
    else if (CardVal = card_value_enum.FOUR):
        return "Four"
    else if (CardVal = card_value_enum.FIVE):
        return "Five"
    else if (CardVal = card_value_enum.SIX):
        return "Six"
    else if (CardVal = card_value_enum.SEVEN):
        return "Seven"
    else if (CardVal = card_value_enum.EIGHT):
        return "Eight"
    else if (CardVal = card_value_enum.NINE):
        return "Nine"
    else if (CardVal = card_value_enum.TEN):
        return "Ten"
    else if (CardVal = card_value_enum.J):
        return "Jack"
    else if (CardVal = card_value_enum.Q):
        return "Queen"
    else if (CardVal = card_value_enum.K):
        return "King"
    else:
        return "Unknown"

# Function to get card as string
GetCardString(Card : card_struct) : string =
    return "{CardValueToString(Card.Value)} of {Card.Suit}"

# Helper method to check if a card exists in an array
CardArrayContains(Cards : []card_struct, SearchCard : card_struct) : logic =
    for (Card : Cards):
        if (Card.Value = SearchCard.Value and Card.Suit = SearchCard.Suit):
            return true
    return false

# Game state management
game_state_enum := enum{
    WAITING_FOR_PLAYERS    # Game hasn't started yet
    DEALING                # Cards are being dealt
    PLAYER_TURN            # Player is deciding what to play
    DECLARATION_MADE       # Player has declared cards
    CHALLENGE_OPPORTUNITY  # Other players can challenge
    RESOLVING_CHALLENGE    # Determining if the challenge was successful
    GAME_OVER              # Game ended, displaying results
}

# Card Selection UI
card_selection_ui := class(creative_device):
    # Game reference - this should be set during initialization
    @editable
    GameDevice : liars_bar_game_device = liars_bar_game_device{}
    
    # Variables to track selected cards
    var SelectedCards : []card_struct = array{}
    var SelectedValue : card_value_enum = card_value_enum.A
    var SelectedCount : int = 1
    
    # UI references - these should be set in the editor
    @editable
    ValueSelector : button_device = button_device{}
    @editable
    CountSelector : button_device = button_device{}
    @editable
    ConfirmButton : button_device = button_device{}
    @editable
    CardSelectionDisplay : text_display_device = text_display_device{}
    
    # Card values array for cycling through
    CardValues : []card_value_enum = array{
        card_value_enum.A, card_value_enum.TWO, card_value_enum.THREE, 
        card_value_enum.FOUR, card_value_enum.FIVE, card_value_enum.SIX, 
        card_value_enum.SEVEN, card_value_enum.EIGHT, card_value_enum.NINE, 
        card_value_enum.TEN, card_value_enum.J, card_value_enum.Q, card_value_enum.K
    }
    
    # Track current player and their hand
    var CurrentPlayer : ?player = option{false}
    var CurrentPlayerHand : []card_struct = array{}
    
    # Initialize UI
    OnBegin<override>()<suspends>:void =
        # Setup event handlers
        ValueSelector.InteractedWithEvent.Subscribe(OnValueChanged)
        CountSelector.InteractedWithEvent.Subscribe(OnCountChanged)
        ConfirmButton.InteractedWithEvent.Subscribe(OnConfirmSelection)
        
        # Initial UI state
        CardSelectionDisplay.SetText("Select cards to play")
        
        # Start hidden until needed
        HideUI()
    
    # Show UI for player selection
    ShowUIForPlayer(Player : player, PlayerHand : []card_struct):void =
        set CurrentPlayer = option{Player}
        set CurrentPlayerHand = PlayerHand
        
        # Reset selection
        set SelectedCards = array{}
        set SelectedValue = card_value_enum.A
        set SelectedCount = 1
        
        # Update UI
        UpdateSelectionUI()
        
        # Enable UI
        ValueSelector.Enable()
        CountSelector.Enable()
        ConfirmButton.Enable()
        
        # Show player's current hand
        DisplayPlayerHand()
    
    # Display the player's current hand
    DisplayPlayerHand():void =
        var HandString : string = "Your Hand:\n"
        
        for (Index := 0..CurrentPlayerHand.Length - 1):
            set HandString += GetCardString(CurrentPlayerHand[Index])
            if (Index < CurrentPlayerHand.Length - 1):
                set HandString += ", "
                if ((Index / 3) * 3 = Index and Index > 0):  # Line break every 3 cards
                    set HandString += "\n"
        
        CardSelectionDisplay.SetText(HandString)
    
    # Hide UI when not needed
    HideUI():void =
        ValueSelector.Disable()
        CountSelector.Disable()
        ConfirmButton.Disable()
        CardSelectionDisplay.SetText("")
    
    # Update the selection UI display
    UpdateSelectionUI():void =
        # First display hand
        DisplayPlayerHand()
        
        # Then add selection info
        CardSelectionDisplay.SetText("{CardSelectionDisplay.GetText()}\n\nSelected: {SelectedCount} {CardValueToString(SelectedValue)}(s)")
    
    # Handle value selection change
    OnValueChanged(Agent : agent):void =
        if (PlayerOpt := player[Agent], CurrentPlayerOpt := CurrentPlayer?, CurrentPlayerOpt <> false and PlayerOpt = CurrentPlayerOpt):
            # Find current index
            var CurrentIndex : int = 0
            for (Index := 0..CardValues.Length - 1):
                if (CardValues[Index] = SelectedValue):
                    set CurrentIndex = Index
                    break
                    
            # Get next value
            NextIndex := ModOperation(CurrentIndex + 1, CardValues.Length)
            set SelectedValue = CardValues[NextIndex]
            
            # Update UI
            UpdateSelectionUI()
    
    # Handle count selection change
    OnCountChanged(Agent : agent):void =
        if (PlayerOpt := player[Agent], CurrentPlayerOpt := CurrentPlayer?, CurrentPlayerOpt <> false and PlayerOpt = CurrentPlayerOpt):
            # Check max cards the player can play
            MaxCards := Math.Min(CurrentPlayerHand.Length, 4)
            
            # Increment count (1 to MaxCards)
            set SelectedCount = ModOperation(SelectedCount, MaxCards) + 1
            
            # Update UI
            UpdateSelectionUI()
    
    # Handle confirmation of selection
    OnConfirmSelection(Agent : agent):void =
        if (PlayerOpt := player[Agent], CurrentPlayerOpt := CurrentPlayer?, CurrentPlayerOpt <> false and PlayerOpt = CurrentPlayerOpt):
            # Select cards from player's hand
            set SelectedCards = SelectCardsFromHand(SelectedCount)
            
            # Hide UI after selection
            HideUI()
            
            # Forward selection to game device with actual selected cards
            GameDevice.ProcessDeclaration(PlayerOpt, SelectedValue, SelectedCount, SelectedCards)
    
    # Select cards from the player's hand
    SelectCardsFromHand(Count : int)<transacts>:[]card_struct =
        var Selected : []card_struct = array{}
        var CardsNeeded : int = Count
        
        # First try to select matching cards
        for (Card : CurrentPlayerHand):
            if (CardsNeeded <= 0):
                break
                
            if (Card.Value = SelectedValue):
                set Selected = Selected + array{Card}
                set CardsNeeded = CardsNeeded - 1
        
        # If we need more cards, select any
        if (CardsNeeded > 0):
            for (Card : CurrentPlayerHand):
                if (CardsNeeded <= 0 or CardArrayContains(Selected, Card)):
                    continue
                    
                set Selected = Selected + array{Card}
                set CardsNeeded = CardsNeeded - 1
        
        return Selected

# Main game device
liars_bar_game_device := class(creative_device):
    # Game properties
    var CurrentGameState : game_state_enum = game_state_enum.WAITING_FOR_PLAYERS
    var Players : []player = array{}
    var CurrentPlayerIndex : int = 0
    var CurrentDeck : []card_struct = array{}
    var DiscardPile : []card_struct = array{}
    var PlayerHands : [player][]card_struct = map{}
    var LastDeclaredValue : card_value_enum = card_value_enum.A
    var LastDeclaredCount : int = 0
    var LastPlayer : ?player = false
    var LastCardsPlayed : []card_struct = array{}
    var MinimumPlayers : int = 2
    
    # UI elements - these should be set in the editor
    @editable
    CardsPlayedTextDisplay : text_display_device = text_display_device{}
    @editable
    PlayerTurnTextDisplay : text_display_device = text_display_device{}
    @editable
    GameStatusDisplay : text_display_device = text_display_device{}
    @editable
    DeclareBtn : button_device = button_device{}
    @editable
    ChallengeBtn : button_device = button_device{}
    @editable
    PassBtn : button_device = button_device{}
    
    # Reference to the card selection UI
    @editable
    CardSelectionUI : card_selection_ui = card_selection_ui{}
    
    # Game settings
    @editable
    CardsPerPlayer : int = 7
    
    # Player notification system
    @editable
    PlayerNotifications : []text_display_device = array{}
    
    # Initialize the game
    OnBegin<override>()<suspends>:void =
        # Set up button listeners
        DeclareBtn.InteractedWithEvent.Subscribe(OnDeclareButtonPressed)
        ChallengeBtn.InteractedWithEvent.Subscribe(OnChallengeButtonPressed)
        PassBtn.InteractedWithEvent.Subscribe(OnPassButtonPressed)
        
        # Link this device to the card selection UI
        CardSelectionUI.GameDevice = self
        
        # Disable buttons initially
        SetButtonsEnabled(false)
        
        # Initialize UI
        GameStatusDisplay.SetText("Waiting for players... Need at least {MinimumPlayers} players.")
        
        # Wait for players to join
        WaitForPlayersToJoin()
    
    # Wait for players to join the game
    WaitForPlayersToJoin()<suspends>:void =
        # Wait until we have minimum required players
        loop:
            set Players = GetPlayspace().GetPlayers()
            if (Players.Length >= MinimumPlayers):
                break
            GameStatusDisplay.SetText("Waiting for players: {Players.Length}/{MinimumPlayers}")
            Sleep(2.0)
        
        # Initialize game
        GameStatusDisplay.SetText("Starting game with {Players.Length} players!")
        Sleep(3.0)
        InitializeGame()
    
    # Set up a new game
    InitializeGame()<suspends>:void =
        # Reset game state
        set CurrentGameState = game_state_enum.DEALING
        set CurrentPlayerIndex = 0
        set DiscardPile = array{}
        set LastCardsPlayed = array{}
        set LastDeclaredValue = card_value_enum.A
        set LastDeclaredCount = 0
        set LastPlayer = option{false}
        
        # Initialize deck
        InitializeDeck()
        
        # Deal cards to players
        DealCards()
        
        # Update UI
        GameStatusDisplay.SetText("Cards dealt. Game starting.")
        Sleep(2.0)
        
        # Start first player turn
        StartPlayerTurn()
    
    # Create a full deck of cards
    InitializeDeck()<transacts>:void =
        var NewDeck : []card_struct = array{}
        
        Suits := array{"Hearts", "Diamonds", "Clubs", "Spades"}
        
        # Define all card values in array for iteration
        CardValues := array{
            card_value_enum.A, card_value_enum.TWO, card_value_enum.THREE,
            card_value_enum.FOUR, card_value_enum.FIVE, card_value_enum.SIX,
            card_value_enum.SEVEN, card_value_enum.EIGHT, card_value_enum.NINE,
            card_value_enum.TEN, card_value_enum.J, card_value_enum.Q, card_value_enum.K
        }
        
        # Add all cards to deck
        for (Suit : Suits):
            for (CardValue : CardValues):
                NewCard := card_struct{Value := CardValue, Suit := Suit}
                set NewDeck = NewDeck + array{NewCard}
        
        # Shuffle deck
        set CurrentDeck = ShuffleDeck(NewDeck)
    
    # Shuffle the deck
    ShuffleDeck(Deck : []card_struct)<transacts>:[]card_struct =
        var ShuffledDeck : []card_struct = array{}
        var TempDeck : []card_struct = Deck
        RandGen := GetRandomNumberGenerator()
        
        # Basic Fisher-Yates shuffle
        loop:
            if (TempDeck.Length <= 0):
                break
                
            RandomIndex := RandGen.GetRandomInt(TempDeck.Length)
            if (RandomIndex >= 0 and RandomIndex < TempDeck.Length):
                Card := TempDeck[RandomIndex]
                set ShuffledDeck = ShuffledDeck + array{Card}
                set TempDeck = RemoveElement(TempDeck, RandomIndex)
        
        return ShuffledDeck
    
    # Helper to remove an element from an array
    RemoveElement(InputArray : []card_struct, IndexToRemove : int)<transacts>:[]card_struct =
        if (IndexToRemove < 0 or IndexToRemove >= InputArray.Length):
            # Invalid index, return original array
            return InputArray
            
        var Result : []card_struct = array{}
        
        for (Index := 0..InputArray.Length - 1):
            if (Index <> IndexToRemove):
                set Result = Result + array{InputArray[Index]}
                
        return Result
    
    # Deal cards to players
    DealCards():void =
        set PlayerHands = map{}
        
        for (Player : Players):
            var PlayerCards : []card_struct = array{}
            
            # Deal cards to player
            for (i := 0..CardsPerPlayer - 1):
                if (CurrentDeck.Length > 0):
                    Card := CurrentDeck[0]
                    set PlayerCards = PlayerCards + array{Card}
                    set CurrentDeck = RemoveElement(CurrentDeck, 0)
            
            # Store player's hand
            PlayerHands[Player] = PlayerCards
            
            # Notify player of their cards
            NotifyPlayerOfHand(Player, PlayerCards)
        
        # Start game
        set CurrentGameState = game_state_enum.PLAYER_TURN
    
    # Notify a player about their current hand
    NotifyPlayerOfHand(Player : player, Cards : []card_struct):void =
        var HandString : string = "Your Hand: "
        
        for (Index := 0..Cards.Length - 1):
            set HandString += GetCardString(Cards[Index])
            if (Index < Cards.Length - 1):
                set HandString += ", "
                if ((Index / 3) * 3 = Index and Index > 0):  # Line break every 3 cards
                    set HandString += "\n"
                    
        # Find player's display device by index
        PlayerIndex := GetPlayerIndex(Player)
        if (PlayerIndex >= 0 and PlayerIndex < PlayerNotifications.Length):
            PlayerNotifications[PlayerIndex].SetText(HandString)
    
    # Get player's index in the players array
    GetPlayerIndex(SearchPlayer : player) : int =
        for (Index := 0..Players.Length - 1):
            if (Players[Index] = SearchPlayer):
                return Index
        return -1
    
    # Start a player's turn
    StartPlayerTurn():void =
        if (Players.Length > 0 and CurrentPlayerIndex < Players.Length):
            CurrentPlayer := Players[CurrentPlayerIndex]
            
            # Update UI
            PlayerTurnTextDisplay.SetText("{CurrentPlayer}'s Turn")
            
            # Check if this is the first turn of the game
            if (LastPlayer = option{false}):
                # First turn, only enable declare button
                SetDeclareButtonEnabled(true)
                SetChallengeButtonEnabled(false)
                SetPassButtonEnabled(false)
                
                GameStatusDisplay.SetText("First turn - you must declare cards")
            else:
                # Not first turn, enable all buttons
                SetDeclareButtonEnabled(true)
                if (LastCardsPlayed.Length > 0):
                    SetChallengeButtonEnabled(true)
                    SetPassButtonEnabled(true)
                    GameStatusDisplay.SetText("Your turn - declare cards, pass, or challenge")
                else:
                    # No cards in play yet, can't challenge
                    SetChallengeButtonEnabled(false)
                    SetPassButtonEnabled(true)
                    GameStatusDisplay.SetText("Your turn - declare cards or pass")
    
    # Enable or disable game buttons
    SetButtonsEnabled(Enabled : logic):void =
        SetDeclareButtonEnabled(Enabled)
        SetChallengeButtonEnabled(Enabled)
        SetPassButtonEnabled(Enabled)
    
    # Helper functions for button enabling/disabling
    SetDeclareButtonEnabled(Enabled : logic):void =
        if (Enabled):
            DeclareBtn.Enable()
        else:
            DeclareBtn.Disable()
    
    SetChallengeButtonEnabled(Enabled : logic):void =
        if (Enabled):
            ChallengeBtn.Enable()
        else:
            ChallengeBtn.Disable()
    
    SetPassButtonEnabled(Enabled : logic):void =
        if (Enabled):
            PassBtn.Enable()
        else:
            PassBtn.Disable()
    
    # Handle declare button press
    OnDeclareButtonPressed(Agent : agent):void =
        if (PlayerOpt := player[Agent], CurrentPlayerIndex < Players.Length and Players[CurrentPlayerIndex] = PlayerOpt):
            # Disable action buttons while declaring
            SetButtonsEnabled(false)
            
            # Show card selection UI for the current player
            if (PlayerHand := PlayerHands[PlayerOpt]?):
                CardSelectionUI.ShowUIForPlayer(PlayerOpt, PlayerHand)
                GameStatusDisplay.SetText("Select cards and declare a value")
            else:
                GameStatusDisplay.SetText("Error: Could not find player's hand")
                StartPlayerTurn()  # Reset turn
    
    # Process the actual declaration after UI selection
    ProcessDeclaration(Player : player, DeclaredValue : card_value_enum, Count : int, SelectedCards : []card_struct):void =
        if (PlayerCards := PlayerHands[Player]?, Count <= PlayerCards.Length):
            # Make sure we have enough cards
            if (SelectedCards.Length <> Count):
                GameStatusDisplay.SetText("Error: Selected cards don't match declared count")
                StartPlayerTurn()  # Reset turn
                return
                
            # Update player's hand by removing played cards
            var RemainingCards : []card_struct = array{}
            for (Card : PlayerCards):
                var CardFound : logic = false
                for (SelectedCard : SelectedCards):
                    if (Card.Value = SelectedCard.Value and Card.Suit = SelectedCard.Suit):
                        set CardFound = true
                        break
                
                if (not CardFound):
                    set RemainingCards = RemainingCards + array{Card}
            
            # Update player's hand
            PlayerHands[Player] = RemainingCards
            
            # Update game state
            set LastCardsPlayed = SelectedCards
            set LastDeclaredValue = DeclaredValue
            set LastDeclaredCount = Count
            set LastPlayer = option{Player}
            set DiscardPile = DiscardPile + SelectedCards
            
            # Update UI
            CardsPlayedTextDisplay.SetText("{Player} declared {Count} {CardValueToString(DeclaredValue)}(s)")
            
            # Check if player has no cards left
            if (RemainingCards.Length = 0):
                CheckWinCondition()
                return
            
            # Update game state
            set CurrentGameState = game_state_enum.CHALLENGE_OPPORTUNITY
            
            # Move to next player
            AdvanceToNextPlayer()
        else:
            GameStatusDisplay.SetText("Invalid declaration")
            StartPlayerTurn()  # Reset turn
    
    # Handle challenge button press
    OnChallengeButtonPressed(Agent : agent):void =
        if (PlayerOpt := player[Agent], CurrentPlayerIndex < Players.Length and Players[CurrentPlayerIndex] = PlayerOpt):
            if (ChallengedPlayer := LastPlayer?, ChallengedPlayer <> false):
                # Disable buttons during challenge resolution
                SetButtonsEnabled(false)
                
                # Set game state
                set CurrentGameState = game_state_enum.RESOLVING_CHALLENGE
                
                # Process the challenge
                ResolveChallengeFor(PlayerOpt, ChallengedPlayer)
    
    # Handle pass button press
    OnPassButtonPressed(Agent : agent):void =
        if (PlayerOpt := player[Agent], CurrentPlayerIndex < Players.Length and Players[CurrentPlayerIndex] = PlayerOpt):
            GameStatusDisplay.SetText("{PlayerOpt} passed their turn")
            
            # Move to next player
            AdvanceToNextPlayer()
    
    # Move to the next player
    AdvanceToNextPlayer():void =
        set CurrentPlayerIndex = ModOperation(CurrentPlayerIndex + 1, Players.Length)
        StartPlayerTurn()
    
    # Resolve a challenge between two players
    ResolveChallengeFor(Challenger : player, ChallengedPlayer : player)<suspends>:void =
        # Count actual cards of declared value
        var ActualCount : int = 0
        
        for (Card : LastCardsPlayed):
            if (Card.Value = LastDeclaredValue):
                set ActualCount = ActualCount + 1
        
        # Determine if challenge was successful (did the player lie?)
        ChallengeFailed := ActualCount >= LastDeclaredCount
        
        # Find who gets the pile
        var PlayerToReceiveCards : player = Challenger  # Default
        
        if (ChallengeFailed):
            # Challenge failed (player told truth), challenger gets cards
            set PlayerToReceiveCards = Challenger
            GameStatusDisplay.SetText("Challenge failed! {ChallengedPlayer} was telling the truth! {Challenger} takes the pile!")
            BroadcastToPlayers("Challenge failed! {ChallengedPlayer} was telling the truth! {Challenger} takes the pile!")
        else:
            # Challenge succeeded (player lied), challenged player gets cards
            set PlayerToReceiveCards = ChallengedPlayer
            GameStatusDisplay.SetText("Challenge succeeded! {ChallengedPlayer} was lying! {ChallengedPlayer} takes the pile!")
            BroadcastToPlayers("Challenge succeeded! {ChallengedPlayer} was lying! {ChallengedPlayer} takes the pile!")
        
        # Show what was actually played
        var RevealText : string = "Revealed cards: "
        for (Index := 0..LastCardsPlayed.Length - 1):
            set RevealText += GetCardString(LastCardsPlayed[Index])
            if (Index < LastCardsPlayed.Length - 1):
                set RevealText += ", "
        
        CardsPlayedTextDisplay.SetText(RevealText)
        
        # Add a delay to let players see the revealed cards
        Sleep(3.0)
        
        # Give cards to player
        if (ExistingHand := PlayerHands[PlayerToReceiveCards]?):
            PlayerHands[PlayerToReceiveCards] = ExistingHand + DiscardPile
        else:
            PlayerHands[PlayerToReceiveCards] = DiscardPile
        
        # Notify player of their new hand
        if (UpdatedHand := PlayerHands[PlayerToReceiveCards]?):
            NotifyPlayerOfHand(PlayerToReceiveCards, UpdatedHand)
        
        # Clear discard pile
        set DiscardPile = array{}
        set LastCardsPlayed = array{}
        
        # Check win condition
        CheckWinCondition()
        
        # Move to next player (the player who received cards goes next)
        for (i := 0..Players.Length - 1):
            if (Players[i] = PlayerToReceiveCards):
                set CurrentPlayerIndex = i
                break
        
        # Reset game state for next turn
        set CurrentGameState = game_state_enum.PLAYER_TURN
        StartPlayerTurn()
    
    # Check if anyone has won the game
    CheckWinCondition():void =
        var WinnerFound : logic = false
        var Winner : ?player = option{false}
        
        # Check if any player has no cards
        for (Player -> Hand : PlayerHands):
            if (Hand.Length = 0):
                set WinnerFound = true
                set Winner = option{Player}
                break
        
        # If we found a winner, end the game
        if (WinnerFound and Winner <> option{false}):
            if (WinningPlayer := Winner?):
                DeclareWinner(WinningPlayer)
    
    # Declare the winner
    DeclareWinner(Winner : player):void =
        set CurrentGameState = game_state_enum.GAME_OVER
        GameStatusDisplay.SetText("Game Over! {Winner} wins!")
        BroadcastToPlayers("Game Over! {Winner} wins!")
        SetButtonsEnabled(false)
        
        # Display final results
        DisplayFinalResults()
    
    # Display final results with card counts
    DisplayFinalResults():void =
        var ResultText : string = "Final Results:\n"
        
        for (i := 0..Players.Length - 1):
            Player := Players[i]
            if (Hand := PlayerHands[Player]?):
                set ResultText += "{Player}: {Hand.Length} cards\n"
        
        CardsPlayedTextDisplay.SetText(ResultText)
    
    # Broadcast a message to all players
    BroadcastToPlayers(Message : string):void =
        for (NotificationDisplay : PlayerNotifications):
            NotificationDisplay.SetText(Message)
        
        # Also show in game status
        GameStatusDisplay.SetText(Message)