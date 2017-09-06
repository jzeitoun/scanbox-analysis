def kwargs_wrapper(kwargs):
        function = kwargs.pop(0)
        function(**kwargs)
