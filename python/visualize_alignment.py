import sys

from align_v2 import generate_visual


def main():
    filename = sys.argv[1]
    print('\nGenerating visualization of alignment.')
    generate_visual([filename])
    print('Done.')

if __name__ == '__main__':
    main()




