import sys
from align import generate_visual

def main():
    filename = sys.argv[1]
    if len(sys.argv) > 2:
        fmt = sys.argv[2]
    else:
        fmt = 'eps'
    generate_visual(filename, fmt)


if __name__ == '__main__':
    main()
