from typing import Collection, Iterator


class TargetSize:
    def __init__(self, length: int, amount: int):
        self.length = length
        self.amount = amount

    def __lt__(self, other):
        return self.length < other.length

    def __str__(self):
        return f"l:{self.length}, n:{self.amount}"


class Job:
    # TODO: make this persistent across restarts to prevent collisions
    current_id = 0

    def __init__(self, length_stock: int, target_sizes: Collection[TargetSize], cut_width: int = 0):
        self._id = Job.current_id
        Job.current_id += 1

        self.length_stock = length_stock
        self.target_sizes = target_sizes
        self.cut_width = cut_width

    # utility

    def get_ID(self):
        return self._id

    def get_sizes(self) -> Iterator[int]:
        # generator, yield all lengths
        for size in self.target_sizes:
            for i in range(size.amount):
                yield size.length

    def __eq__(self, other):
        """
        Equality by ID, not by values
        """
        return self._id == other.get_ID()

    def __len__(self):
        """
        Number of target sizes in job
        """
        return sum(target.amount for target in self.target_sizes)
