for x in `find -name *.ko`
do
    ln -s $x .
done
