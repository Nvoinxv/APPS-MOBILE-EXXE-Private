class TradeIdeasModel:
    def __init__(self, id=None, Trade_ideas = None,
                 tipe_trade=None, Aktivasi=None,
                 Date=None, Entry=None, Stoploss=None,
                 Target=None, Status=None):
        self.id = id
        self.Trade_ideas = Trade_ideas
        self.tipe_trade = tipe_trade
        self.aktivasi = Aktivasi
        self.Date= Date
        self.Entry = Entry
        self.Stoploss = Stoploss
        self.Target = Target
        self.Status = Status

    def __str__(self):
        return f"ID: {self.id} | {self.Trade_ideas} | {self.tipe_trade} | Entry: {self.Entry} | SL: {self.Stoploss} | TP: {self.Target} | Status: {self.Status}"
    
    def to_dict(self):
        return {
            "_id": self.id,
            "Trade_ideas": self.Trade_ideas,
            "Tipe_trade": self.tipe_trade,
            "aktivasi": self.aktivasi,
            "Date": self.Date,
            "Entry": self.Entry,
            "Stoploss": self.Stoploss,
            "Target": self.Target,
            "Status": self.Status
        }
    
    def from_dict(cls, data:dict):
        return cls (
            id = data.get("_id"),
            Trade_ideas = data.get("Trade_ideas"),
            Tipe_trade = data.get("Tipe_trades"),
            aktivasi = data.get("aktivasi"),
            Date = data.get("Date"),
            Entry = data.get("Entry"),
            Stoploss = data.get("Stoploss"),
            Target = data.get("Target"),
            Status = data.get("Status")
        )