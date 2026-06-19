import json
import os

class DataManager:
    """
    Handles loading and saving the application state (staff, services, bookings)
    to and from a persistent JSON file.
    """
    def __init__(self, filepath="data/booking_data.json"):
        self.filepath = filepath
        self.staff = []
        self.services = []
        self.bookings = []
        self.load_state()

    def load_state(self):
        """Loads the state from the JSON file."""
        if not os.path.exists(self.filepath):
            print(f"State file not found at {self.filepath}. Initializing with empty data.")
            # Initialize default data if the file doesn't exist (for first run)
            self.staff = [
                {"id": 1, "name": "Alice", "specialty": "Massage", "availability": {"Monday": ["09:00", "10:00"]}}
            ]
            self.services = [
                {"id": 101, "name": "Swedish Massage", "duration": 60, "price": 80},
                {"id": 102, "name": "Hot Stone Therapy", "duration": 90, "price": 120}
            ]
            self.bookings = []
            self._save_state_internal() # Save the initial empty state
            return

        try:
            with open(self.filepath, 'r') as f:
                data = json.load(f)
                self.staff = data.get("staff", [])
                self.services = data.get("services", [])
                self.bookings = data.get("bookings", [])
            print(f"State successfully loaded from {self.filepath}.")
        except json.JSONDecodeError:
            print(f"Error decoding JSON from {self.filepath}. Initializing with default data.")
            self.staff = []
            self.services = []
            self.bookings = []
        except Exception as e:
            print(f"An unexpected error occurred loading state: {e}. Initializing empty state.")
            self.staff = []
            self.services = []
            self.bookings = []

    def _get_data(self):
        """Returns a dictionary representation of the current state."""
        return {
            "staff": self.staff,
            "services": self.services,
            "bookings": self.bookings
        }

    def _save_state_internal(self):
        """Saves the current state to the JSON file."""
        try:
            # Ensure the directory exists
            os.makedirs(os.path.dirname(self.filepath), exist_ok=True)
            
            data = self._get_data()
            with open(self.filepath, 'w') as f:
                json.dump(data, f, indent=4)
            print(f"\n--- State saved successfully to {self.filepath} ---")
        except Exception as e:
            print(f"\n!!! ERROR saving state to {self.filepath}: {e} !!!")

    def save_state(self):
        """Public method to save the state, typically called after a modification."""
        self._save_state_internal()

# Global instance for easy access (or pass it through dependency injection)
data_manager = DataManager()
