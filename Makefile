clean:
	dzil clean
	rm -rf _Inline
	rm -rf t/_Inline
	rm -rf blib

clean2:
	rm -rf _Inline
	rm -rf t/_Inline
	rm -rf blib

test: clean
	dzil test	

prepare: clean
	dzil build 
	mv -vf *.tar.gz ./releases/ 
	dzil clean
	git add ./releases/*.tar.gz
	git status
	@echo "tag and push ... "
