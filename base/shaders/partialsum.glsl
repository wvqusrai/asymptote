layout(local_size_x=PROCESSORS) in;

uniform uint elements;

layout(binding=0, std430) buffer sumBuffer
{
  uint sum[];
};

layout(binding=1, std430) buffer offsetBuffer
{
  uint offset[];
};

shared uint sharedData[PROCESSORS];

uint ceilquotient(uint a, uint b)
{
  return (a+b-1u)/b;
}

void main(void)
{
  uint id=gl_LocalInvocationID.x;
  sharedData[id]=sum[id];

  barrier();

  uint index=id << 1u;
  sharedData[index+1u] += sharedData[index];
  barrier();
  for(uint step=1u; step < STEPSM1; step++) {
    uint mask=(1u << step)-1u;
    uint index=((id >> step) << (step+1u))+mask;
    uint windex=index+(id&mask)+1u;
    sharedData[windex] += sharedData[index];
    barrier();
  }
  uint mask=(1u << STEPSM1)-1u;
  index=((id >> STEPSM1) << (STEPSM1+1u))+mask;
  uint windex=index+(id&mask)+1u;
  if(windex < PROCESSORS)
    sharedData[windex] += sharedData[index];
  barrier();

  uint id1=id+1u;
  if(id1 < PROCESSORS) {
    uint m=elements/PROCESSORS;
    uint row=m*id1+min(id1,elements-m*PROCESSORS);
    offset[row] += sharedData[id];
  } else
    sum[0]=sharedData[id];  // Store fragment size in sum[0]
}
