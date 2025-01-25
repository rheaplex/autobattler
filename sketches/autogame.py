import random
from dataclasses import dataclass, field
from typing import List, Optional

@dataclass
class Card:
    name: str
    attack: int
    health: int
    level: int = 1

    # Example "ability trigger" placeholders
    # In a real game, you'd have more complex logic or a system
    # for different triggers (start of battle, faint, etc.)
    def on_buy(self):
        # Trigger any "on buy" effects here
        pass

    def on_faint(self, friendly_team, enemy_team):
        # Trigger any "on faint" effects here (like summoning a token)
        pass

    def on_hurt(self):
        # Trigger any "on hurt" logic if applicable
        pass

@dataclass
class ShopSlot:
    """Represents a single slot in the shop (card or energy)."""
    card: Optional[Card] = None
    energy: Optional[str] = None
    cost: int = 3

@dataclass
class Shop:
    """Represents the in-game shop with multiple slots for cards and energy."""
    card_slots: List[ShopSlot] = field(default_factory=list)
    energy_slots: List[ShopSlot] = field(default_factory=list)

    def roll(self):
        """Refresh (randomize) the shop's content."""
        # In a real game, you'd draw from weighted pools or tiers
        for slot in self.card_slots:
            slot.card = Card(
                name="RandomCard" + str(random.randint(1, 100)),
                attack=random.randint(1, 3),
                health=random.randint(1, 3)
            )
        for slot in self.energy_slots:
            slot.energy = random.choice(["Apple", "Honey", "Garlic"])

@dataclass
class Player:
    """Holds player's team, credits, lives, ribbons, etc."""
    credits: int = 10
    lives: int = 10
    ribbons: int = 0
    team: List[Card] = field(default_factory=list)

    def buy_card(self, shop_slot: ShopSlot) -> bool:
        """Attempt to buy a card from the shop slot."""
        if self.credits >= shop_slot.cost and len(self.team) < 5:
            self.credits -= shop_slot.cost
            card = shop_slot.card
            if card:
                card.on_buy()
                self.team.append(card)
                # Remove card from shop slot
                shop_slot.card = None
            return True
        return False

    def sell_card(self, card_index: int) -> None:
        """Sell a card from the team, returning some credits."""
        if 0 <= card_index < len(self.team):
            # In a real game, triggers like on-sell would be applied here
            self.team.pop(card_index)
            self.credits += 1  # Typically you get 1 credit back

    def combine_cards(self, idx1: int, idx2: int):
        """Combine two of the same card to level up."""
        if (
            0 <= idx1 < len(self.team)
            and 0 <= idx2 < len(self.team)
            and self.team[idx1].name == self.team[idx2].name
        ):
            # Combine stats/level
            self.team[idx1].level += 1
            self.team[idx1].attack = max(self.team[idx1].attack, self.team[idx2].attack) + 1
            self.team[idx1].health = max(self.team[idx1].health, self.team[idx2].health) + 1

            # Remove second card
            del self.team[idx2]

@dataclass
class Game:
    """Main game class to manage turns, battles, and progression."""
    player: Player = field(default_factory=Player)
    turn: int = 1
    shop: Shop = field(default_factory=lambda: Shop(
        card_slots=[ShopSlot() for _ in range(3)],
        energy_slots=[ShopSlot(energy=None) for _ in range(2)]
    ))

    def start_turn(self):
        """Setup the turn: reset credits, roll the shop if needed, etc."""
        self.player.credits = 10
        # Adjust available tier based on turn number in a real game
        self.shop.roll()
        print(f"--- Turn {self.turn} ---")
        print(f"Player lives: {self.player.lives}, ribbons: {self.player.ribbons}")

    def shop_phase(self):
        """Player logic to buy/sell/combine as they wish."""
        # In a real scenario, you'd have an interface or AI deciding these actions.
        # For now, let's do something random or skip for brevity.
        pass

    def battle_phase(self, enemy_player: Player):
        """Auto-battle between the player and an enemy."""
        print("Battle starts!")
        # Make copies so we don't mutate original teams
        our_team = [Card(p.name, p.attack, p.health, p.level) for p in self.player.team]
        their_team = [Card(p.name, p.attack, p.health, p.level) for p in enemy_player.team]

        # Start-of-battle triggers would go here

        # Loop until one side is down
        while our_team and their_team:
            # Front cards fight
            front_our = our_team[0]
            front_their = their_team[0]
            print(f"{front_our.name} vs. {front_their.name}")
            
            # Simultaneous damage exchange
            front_our.health -= front_their.attack
            front_their.health -= front_our.attack

            # Check for faint
            if front_our.health <= 0:
                # Trigger on-faint
                front_our.on_faint(our_team, their_team)
                our_team.pop(0)
            if front_their.health <= 0 and their_team:
                front_their.on_faint(their_team, our_team)
                their_team.pop(0)

        # Determine winner/loser or draw
        if our_team and not their_team:
            print("You won the battle!")
            self.player.ribbons += 1
        elif their_team and not our_team:
            print("You lost the battle!")
            self.player.lives -= 2  # Example: lose 2 lives
        else:
            print("It's a draw.")
            # Some modes might penalize or skip changes on draw
        print()

    def run_turn(self):
        """Run a single turn of the game."""
        self.start_turn()
        self.shop_phase()

        # For illustration, let's create a dummy enemy with random cards
        enemy = Player(team=[
            Card("EnemyCardA", 2, 2),
            Card("EnemyCardB", 3, 1)
        ])

        self.battle_phase(enemy)
        self.turn += 1

    def is_game_over(self):
        """Check if run is over (lives depleted or ribbons maxed)."""
        if self.player.lives <= 0:
            print("Game Over. You ran out of lives.")
            return True
        if self.player.ribbons >= 10:
            print("Victory! You reached 10 ribbons.")
            return True
        return False

    def run_game(self):
        """Main loop until game ends."""
        while not self.is_game_over():
            self.run_turn()
        print("Thanks for playing!")

# -----------------------------
# Example usage (command line)
# -----------------------------
if __name__ == "__main__":
    game = Game()
    game.player.team = [
        Card("CardA", 1, 3),
        Card("CardB", 3, 7)
    ]
    game.run_game()
