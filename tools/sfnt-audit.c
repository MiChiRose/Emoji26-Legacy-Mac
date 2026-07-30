#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned long u32(FILE *f, long p) { unsigned char b[4]; fseek(f,p,SEEK_SET); if(fread(b,1,4,f)!=4) return 0; return ((unsigned long)b[0]<<24)|((unsigned long)b[1]<<16)|((unsigned long)b[2]<<8)|b[3]; }
static unsigned int u16(FILE *f, long p) { unsigned char b[2]; fseek(f,p,SEEK_SET); if(fread(b,1,2,f)!=2) return 0; return ((unsigned)b[0]<<8)|b[1]; }
int main(int argc,char **argv) { FILE *f; long base=0,i; unsigned int n; int sbix=0,cmap=0,gsub=0;
 if(argc!=2 || !(f=fopen(argv[1],"rb"))) return 64;
 if(u32(f,0)==0x74746366UL) { base=(long)u32(f,12); printf("container=TTC\n"); } else printf("container=SFNT\n");
 n=u16(f,base+4); if(n==0 || n>4096) { fprintf(stderr,"Invalid SFNT directory\n"); fclose(f); return 2; }
 printf("tables:"); for(i=0;i<n;i++) { unsigned long t=u32(f,base+12+i*16); char s[5]; s[0]=t>>24;s[1]=t>>16;s[2]=t>>8;s[3]=t;s[4]=0; printf(" %s",s); if(!strcmp(s,"sbix"))sbix=1; if(!strcmp(s,"cmap"))cmap=1; if(!strcmp(s,"GSUB"))gsub=1; } puts("");
 printf("sbix=%s cmap=%s GSUB=%s\n",sbix?"present":"absent",cmap?"present":"absent",gsub?"present":"absent"); fclose(f); return cmap?0:2; }
