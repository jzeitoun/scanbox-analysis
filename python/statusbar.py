import psutil

import sys

class Statusbar(object):
    """
    Creates a progress bar.

    Parameters
    ----------
    num_tasks: int
        Total number of tasks to be completed.
    title: str, optional
        Title for progress bar. Default is None.
    barsize: int, optional
        Total number of bars to use for length of progress bar. Default is
        50.
    mem_monitor: bool, optional
        Include a display of available memory and abort execution if
        available memory drops below threshold.
    mem_thresh: int, optional
        If available memory drops below this level, execution is aborted.
        Units are in GB. Default is 1.

    Returns
    -------
    None
    """

    def __init__(self, num_tasks, title=None, barsize=50, mem_monitor=False,
            mem_thresh=1):
        self._title = title
        self._barsize = barsize
        self._num_tasks = num_tasks
        self._mem_monitor = mem_monitor
        self._mem_thresh = mem_thresh * 1024 * 1024 * 1024

    def initialize(self):
        sys.stdout.write('\r')
        if self._title is not None:
            sys.stdout.write(self._title + '\n')
        sys.stdout.write('[{:{}s}] {}%'.format('=' * 0, self._barsize, 0))
        if self._mem_monitor:
            memory_stats = psutil.virtual_memory()
            available = memory_stats.available
            sys.stdout.write('\nAvailable Memory: {:.2f}GB'.format(available/10**9))
        sys.stdout.flush()

    def update(self, bars):
        fraction_complete = bars/float(self._num_tasks)
        increment = int(self._barsize * fraction_complete)
        percent_increment = 100 * fraction_complete
        if self._mem_monitor:
            sys.stdout.write('\033[F')
        sys.stdout.write('\r')
        sys.stdout.write('[{:{}s}] {:.2f}%'.format('=' * increment, self._barsize, percent_increment))
        if self._mem_monitor:
            memory_stats = psutil.virtual_memory()
            available = memory_stats.available
            if available < self._mem_thresh:
                raise MemoryError('Not enough memory available to continue. Aborting.')
                #sys.exit()
            else:
                sys.stdout.write('\nAvailable Memory: {:.2f}GB'.format(available/10**9))
        sys.stdout.flush()

