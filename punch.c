#define _GNU_SOURCE
#include<fcntl.h>
#include<unistd.h>
#include<stdio.h>
#include<stdlib.h>

int main(int argc, char* argv[]){
	long long x = 250966470656;
	if(argc < 2){ printf("i need file to work with\n"); return 0; }
	int fd;
	printf("punching %s...\n", argv[1]);
	if(argc == 3){ x=atoi(argv[2])*1048576; printf("size=%lld bytes\n", x);}
	for(long long j = 3; j <= 10; j+=7){
		fd = open(argv[1], O_RDWR);
		if(fd == -1){ printf("file doesnt exist?\n"); return 0;}
		for(long long i = 0; i < x; i += 4096*j){
			printf("\r%lld percent...  %lld", 100/j, i);
			fallocate(fd, FALLOC_FL_PUNCH_HOLE|FALLOC_FL_KEEP_SIZE, i, 4096);
		}
		printf("\n");
		close(fd);
	}
	printf("done\n");
	
	return 0;
}
