private import math;

triple O=(0,0,0);
triple X=(1,0,0), Y=(0,1,0), Z=(0,0,1);

real[] operator ecast(triple v)
{
  return new real[] {v.x, v.y, v.z, 1};
}

triple operator ecast(real[] a)
{
  if(a.length != 4) abort("vector length of "+(string) a.length+" != 4");
  if(a[3] == 0) abort("camera is too close to object");
  return (a[0],a[1],a[2])/a[3];
}

typedef real[][] transform3;

// Alias the math operation of multiplying matrices.
transform3 operator * (transform3 a, transform3 b)=math.operator *;

triple operator * (transform3 t, triple v)
{
  return (triple) (t*(real[]) v);
}

// A translation in 3D space.
transform3 shift(triple v)
{
  transform3 t=identity(4);
  t[0][3]=v.x;
  t[1][3]=v.y;
  t[2][3]=v.z;
  return t;
}

// Avoid two parentheses.
transform3 shift(real x, real y, real z)
{
  return shift((x,y,z));
}

// A uniform scaling in 3D space.
transform3 scale3(real s)
{
  transform3 t=identity(4);
  t[0][0]=t[1][1]=t[2][2]=s;
  return t;
}

// A scaling in the x direction in 3D space.
transform3 xscale3(real s)
{
  transform3 t=identity(4);
  t[0][0]=s;
  return t;
}

// A scaling in the y direction in 3D space.
transform3 yscale3(real s)
{
  transform3 t=identity(4);
  t[1][1]=s;
  return t;
}

// A scaling in the z direction in 3D space.
transform3 zscale3(real s)
{
  transform3 t=identity(4);
  t[2][2]=s;
  return t;
}

// A transformation representing rotation by an angle in degrees about
// an axis v through the origin (in the right-handed direction).
transform3 rotate(real angle, triple v)
{
  v=unit(v);
  real x=v.x, y=v.y, z=v.z;
  real s=Sin(angle), c=Cos(angle), t=1-c;

  return new real[][] {
    {t*x^2+c,   t*x*y-s*z, t*x*z+s*y, 0},
      {t*x*y+s*z, t*y^2+c,   t*y*z-s*x, 0},
        {t*x*z-s*y, t*y*z+s*x, t*z^2+c,   0},
          {0,         0,         0,         1}};
}

// A transformation representing rotation by an angle in degrees about
// the line u--v (in the right-handed direction).
transform3 rotate(real angle, triple u, triple v)
{
  return shift(u)*rotate(angle,v-u)*shift(-u);
}

transform3 reflect(triple u, triple v, triple w)
{
  triple normal=cross(v-u,w-u);
  if(normal == O)
    abort("points determining plane to reflect about cannot be colinear");
  transform3 basis=shift(u);
  if(normal.x != 0 || normal.y != 0)
    basis *= rotate(longitude(normal,warn=false),Z)*
      rotate(colatitude(normal),Y);
  
  return basis*zscale3(-1)*inverse(basis);
}

typedef pair project(triple v);

// Project u onto v.
triple project(triple u, triple v)
{
  v=unit(v);
  return dot(u,v)*v;
}

// Transformation corresponding to moving the camera from 'target'
// (looking down the negative z axis) to the point 'eye' (looking at
// target), orienting the camera so that direction 'up' points upwards.
// Since, in actuality, we are transforming the points instead of
// the camera, we calculate the inverse matrix.
// Based on the gluLookAt implementation in the OpenGL manual.
transform3 lookAt(triple target, triple eye, triple up=Z)
{
  triple f=unit(target-eye);
  if(f == O)
    // The target is the same as the eye, so just move to the eye, and don't
    // try to point in any particular direction.
    return shift(-eye);

  triple side=cross(f,up);
  if(side == O)
    // The camera is pointing either directly up or down, so there is no
    // preferred "up" direction to rotate it.  Pick one arbitrarily.
    return lookAt(target, eye, cross(f,Y) != O ? Y : Z);
  triple s=unit(side);

  triple u=cross(s,f);

  transform3 M=new real[][] {{ s.x,  s.y,  s.z, 0},
                             { u.x,  u.y,  u.z, 0},
                             {-f.x, -f.y, -f.z, 0},
                             {   0,    0,    0, 1}};
  return M*shift(-eye);
}


// Return a matrix to do perspective distortion based on a triple v.
transform3 distort(triple v) 
{
  transform3 t=identity(4);
  real d=length(v);
  t[3][2]=-1/d;
  t[3][3]=0;
  return t;
}

struct projection {
  triple camera;
  transform3 project;
  transform3 aspect;
  projection copy() {
    projection P=new projection;
    P.camera=camera;
    P.project=project;
    P.aspect=aspect;
    return P;
  }
}

projection currentprojection;

// With this, save() and restore() in plain also save and restore the
// currentprojection.
addSaveFunction(new restoreThunk() {
    projection P=currentprojection.copy();
    return new void() {
      currentprojection=P;
    };
  });


projection projection(triple camera, transform3 project,
                      transform3 aspect=identity(4))
{
  projection P;
  P.camera=camera;
  P.project=project;
  P.aspect=aspect;
  return P;
}

// Uses the homogenous coordinate to perform perspective distortion.  When
// combined with a projection to the XY plane, this effectively maps
// points in three space to a plane at a distance d from the camera.
projection perspective(triple camera, triple up=Z)
{
  return projection(camera,distort(camera)*lookAt(O,camera,up));
}

projection perspective(real x, real y, real z, triple up=Z)
{
  return perspective((x,y,z),up);
}

projection orthographic(triple camera, triple up=Z)
{
  return projection(camera,lookAt(O,camera,up));
}

projection orthographic(real x, real y, real z, triple up=Z)
{
  return orthographic((x,y,z),up);
}

projection oblique(real angle=45)
{
  transform3 t=identity(4);
  real c2=Cos(angle)^2;
  real s2=1-c2;
  t[0][2]=-c2;
  t[1][2]=-s2;
  t[2][2]=0;
  return projection((c2,s2,1),t);
}

projection obliqueZ(real angle=45) {return oblique(angle);}

projection obliqueX(real angle=45)
{
  transform3 t=identity(4);
  real c2=Cos(angle)^2;
  real s2=1-c2;
  t[0][0]=-c2;
  t[1][0]=-s2;
  t[1][1]=0;
  t[0][1]=1;
  t[1][2]=1;
  t[2][2]=0;
  return projection((1,c2,s2),t);
}

projection obliqueY(real angle=45)
{
  transform3 t=identity(4);
  real c2=Cos(angle)^2;
  real s2=1-c2;
  t[0][1]=c2;
  t[1][1]=s2;
  t[1][2]=1;
  t[2][2]=0;
  return projection((c2,-1,s2),t);
}

projection oblique=oblique();
projection obliqueX=obliqueX(), obliqueY=obliqueY(), obliqueZ=obliqueZ();

currentprojection=perspective(5,4,2);

transform3 aspect(projection P)
{
  return P.project*P.aspect;
}

// Map pair z onto a triple by inverting the projection P onto the 
// plane perpendicular to normal and passing through point.
triple invert(pair z, triple normal, triple point,
              projection P=currentprojection)
{
  transform3 t=aspect(P);
  real[][] A={{t[0][0]-z.x*t[3][0],t[0][1]-z.x*t[3][1],t[0][2]-z.x*t[3][2]},
              {t[1][0]-z.y*t[3][0],t[1][1]-z.y*t[3][1],t[1][2]-z.y*t[3][2]},
              {normal.x,normal.y,normal.z}};
  real[] b={z.x*t[3][3],z.y*t[3][3],dot(normal,point)};
  real[] x=solve(A,b);
  return (x[0],x[1],x[2]);
}

void scale(projection dest=currentprojection, real x, real y, real z)
{
  dest.aspect=xscale3(x)*yscale3(y)*zscale3(z);
}

pair xypart(triple v)
{
  return (v.x,v.y);
}

project operator cast(transform3 t)
{
  return new pair(triple v) {
    return xypart(t*v);
  };
}

struct control {
  triple post,pre;
  bool active=false;
  void init(triple post, triple pre) {
    this.post=post;
    this.pre=pre;
    active=true;
  }
}

control nocontrol;
  
control operator * (transform3 t, control c) 
{
  control C;
  C.post=t*c.post;
  C.pre=t*c.pre;
  C.active=c.active;
  return C;
}

void write(file file, control c)
{
  write(file,".. controls ");
  write(file,c.post);
  write(file," and ");
  write(file,c.pre);
}
  
struct Tension {
  real out,in;
  bool atLeast;
  bool active;
  void init(real out=1, real in=1, bool atLeast=false, bool active=true) {
    real check(real val) {
      if(val < 0.75) abort("tension cannot be less than 3/4");
      return val;
    }
    this.out=check(out);
    this.in=check(in);
    this.atLeast=atLeast;
    this.active=active;
  }
}

Tension operator init()
{
  Tension t=new Tension;
  t.init(false);
  return t;
}

Tension noTension;
  
void write(file file, Tension t)
{
  write(file,"..tension ");
  if(t.atLeast) write(file,"atleast ");
  write(file,t.out);
  write(file," and ");
  write(file,t.in);
}
  
struct dir {
  triple dir;
  real gamma=1; // endpoint curl
  bool Curl;    // curl specified
  bool active() {
    return dir != O || Curl;
  }
  void init(triple v) {
    this.dir=v;
  }
  void init(real gamma) {
    this.gamma=gamma;
    this.Curl=true;
  }
  void init(dir d) {
    dir=d.dir;
    gamma=d.gamma;
    Curl=d.Curl;
  }
  void default(triple v) {
    if(!active()) init(v);
  }
  void default(dir d) {
    if(!active()) init(d);
  }
  dir copy() {
    dir d=new dir;
    d.init(this);
    return d;
  }
}

void write(file file, dir d)
{
  if(d.dir != O) {
    write(file,"{"); write(file,unit(d.dir)); write(file,"}");
  } else if(d.Curl) {
    write(file,"{curl3 "); write(file,d.gamma); write(file,"}");
  }
}
  
transform3 shiftless(transform3 t)
{
  transform3 T=copy(t);
  T[0][3]=T[1][3]=T[2][3]=0;
  return T;
}

dir operator * (transform3 t, dir d) 
{
  dir D=d.copy();
  D.init(unit(shiftless(t)*d.dir));
  return D;
}

struct flatguide3 {
  triple[] nodes;
  bool[] cyclic;     // true if node is really a cycle
  control[] control; // control points for segment starting at node
  Tension[] Tension; // Tension parameters for segment starting at node
  dir[] in,out;      // in and out directions for segment starting at node

  bool cyclic() {return cyclic[cyclic.length-1];}
  
  int size() {
    return cyclic() ? nodes.length-1 : nodes.length;
  }
  
  void node(triple v, bool b=false) {
    nodes.push(v);
    control.push(nocontrol);
    Tension.push(noTension);
    in.push(new dir);
    out.push(new dir);
    cyclic.push(b);
  }

  void control(triple post, triple pre) {
    if(control.length > 0) {
      control c;
      c.init(post,pre);
      control[control.length-1]=c;
    }
  }

  void Tension(real out, real in, bool atLeast) {
    if(Tension.length > 0) {
      Tension t;
      t.init(out,in,atLeast);
      Tension[Tension.length-1]=t;
    }
  }

  void in(triple v) {
    if(in.length > 0) {
      in[in.length-1].init(v);
    }
  }

  void out(triple v) {
    if(out.length > 0) {
      out[out.length-1].init(v);
    }
  }

  void in(real gamma) {
    if(in.length > 0) {
      in[in.length-1].init(gamma);
    }
  }

  void out(real gamma) {
    if(out.length > 0) {
      out[out.length-1].init(gamma);
    }
  }

  void cyclic() {
    if(nodes.length > 0)
      node(nodes[0],true);
  }
  
  // Return true if outgoing direction at node i is known.
  bool solved(int i) {
    return out[i].active() || control[i].active;
  }
}

void write(file file, string s="", explicit flatguide3 x, suffix suffix=none)
{
  write(file,s);
  if(x.size() == 0) write(file,"<nullpath3>");
  else for(int i=0; i < x.nodes.length; ++i) {
      if(i > 0) write(file,endl);
      if(x.cyclic[i]) write(file,"cycle3");
      else write(file,x.nodes[i]);

      if(x.control[i].active) // Explicit control points trump other specifiers
        write(file,x.control[i]);
      else {
        write(file,x.out[i]);
        if(x.Tension[i].active) write(file,x.Tension[i]);
      }
      if(i < x.nodes.length-1) write(file,"..");
      if(!x.control[i].active) write(file,x.in[i]);
    }
  write(file,suffix);
}

void write(string s="", flatguide3 x, suffix suffix=endl)
{
  write(stdout,s,x,suffix);
}

void write(file file, string s="", flatguide3[] x, suffix suffix=none)
{
  write(file,s);
  if(x.length > 0) write(file,x[0]);
  for(int i=1; i < x.length; ++i) {
    write(file,endl);
    write(file," ^^");
    write(file,x[i]);
  }
  write(file,suffix);
}

void write(string s="", flatguide3[] x, suffix suffix=endl)
{
  write(stdout,s,x,suffix);
}

// A guide3 is most easily represented as something that modifies a flatguide3.
typedef void guide3(flatguide3);

void nullpath3(flatguide3) {};

guide3 operator init() {return nullpath3;}

guide3 operator cast(triple v)
{
  return new void(flatguide3 f) {
    f.node(v);
  };
}

guide3[] operator cast(triple[] v)
{
  guide3[] g=new guide3[v.length];
  for(int i=0; i < v.length; ++i)
    g[i]=v[i];
  return g;
}

void cycle3(flatguide3 f)
{
  f.cyclic();
}

guide3 operator controls(triple post, triple pre) 
{
  return new void(flatguide3 f) {
    f.control(post,pre);
  };
};
  
guide3 operator controls(triple v)
{
  return operator controls(v,v);
}

guide3 operator tension3(real out, real in, bool atLeast)
{
  return new void(flatguide3 f) {
    f.Tension(out,in,atLeast);
  };
};
  
guide3 operator tension3(real t, bool atLeast)
{
  return operator tension3(t,t,atLeast);
}

guide3 operator curl3(real gamma, int p)
{
  return new void(flatguide3 f) {
    if(p == 0) f.out(gamma);
    else if(p == 1) f.in(gamma);
  };
}
  
guide3 operator spec(triple v, int p)
{
  return new void(flatguide3 f) {
    if(p == 0) f.out(v);
    else if(p == 1) f.in(v);
  };
}
  
guide3 operator -- (... guide3[] g)
{
  return new void(flatguide3 f) {
    if(g.length > 0) {
      for(int i=0; i < g.length-1; ++i) {
        g[i](f);
        f.out(1);
        f.in(1);
      }
      g[g.length-1](f);
    }
  };
}

guide3 operator .. (... guide3[] g)
{
  return new void(flatguide3 f) {
    for(int i=0; i < g.length; ++i)
      g[i](f);
  };
}

guide3 operator ::(... guide3[] a)
{
  if(a.length == 0) return nullpath3;
  guide3 g=a[0];
  for(int i=1; i < a.length; ++i)
    g=g..operator tension3(1,true)..a[i];
  return g;
}

guide3 operator ---(... guide3[] a)
{
  if(a.length == 0) return nullpath3;
  guide3 g=a[0];
  for(int i=1; i < a.length; ++i)
    g=g..operator tension3(infinity,true)..a[i];
  return g;
}

flatguide3 operator cast(guide3 g)
{
  flatguide3 f;
  g(f);
  return f;
}

flatguide3[] operator cast(guide3[] g)
{
  flatguide3[] p=new flatguide3[g.length];
  for(int i=0; i < g.length; ++i) {
    flatguide3 f;
    g[i](f);
    p[i]=f;
  }
  return p;
}

guide3 operator * (transform3 t, guide3 g) 
{
  return new void(flatguide3 f) {
    g(f);
    for(int i=0; i < f.nodes.length; ++i) {
      f.nodes[i]=t*f.nodes[i];
      f.cyclic[i]=f.cyclic[i];
      f.control[i]=t*f.control[i];
      f.Tension[i]=f.Tension[i];
      f.in[i]=t*f.in[i];
      f.out[i]=t*f.out[i];
    }
  };
}

guide3[] operator * (transform3 t, guide3[] g) 
{
  guide3[] G=new guide3[g.length];
  for(int i=0; i < g.length; ++i)
    G[i]=t*g[i];
  return G;
}

// A version of acos that tolerates numerical imprecision
real acos1(real x)
{
  if(x < -1) x=-1;
  if(x > 1) x=1;
  return acos(x);
}
  
struct Controls {
  triple c0,c1;

  // 3D extension of John Hobby's control point formula
  //  (The MetaFont Book, page 131).
  void init(triple v0, triple v1, triple d0, triple d1, real tout, real tin,
            bool atLeast) {
    triple v=v1-v0;
    triple u=unit(v);
    real L=length(v);
    d0=unit(d0);
    d1=unit(d1);
    real theta=acos1(dot(d0,u));
    real phi=acos1(dot(d1,u));
    if(dot(cross(d0,v),cross(v,d1)) < 0) phi=-phi;
    c0=v0+d0*L*relativedistance(theta,phi,tout,atLeast);
    c1=v1-d1*L*relativedistance(phi,theta,tin,atLeast);
  }
}

private triple cross(triple d0, triple d1, triple camera)
{
  triple normal=cross(d0,d1);
  return normal == O ? camera : normal;
}
                                        
private triple dir(real theta, triple d0, triple d1, triple camera)
{
  triple normal=cross(d0,d1,camera);
  return rotate(degrees(theta),dot(normal,camera) >= 0 ? normal : -normal)*d1;
}

private real angle(triple d0, triple d1, triple camera)
{
  real theta=acos1(dot(unit(d0),unit(d1)));
  return dot(cross(d0,d1,camera),camera) >= 0 ? theta : -theta;
}

// 3D extension of John Hobby's angle formula (The MetaFont Book, page 131).
// Notational differences: here psi[i] is the turning angle at z[i+1],
// beta[i] is the tension for segment i, and in[i] is the incoming
// direction for segment i (where segment i begins at node i).

real[] theta(triple[] v, real[] alpha, real[] beta, 
             triple dir0, triple dirn, real g0, real gn, triple camera)
{
  real[] a,b,c,f,l,psi;
  int n=alpha.length;
  bool cyclic=v.cyclicflag;
  for(int i=0; i < n; ++i)
    l[i]=1/length(v[i+1]-v[i]);
  int i0,in;
  if(cyclic) {i0=0; in=n;}
  else {i0=1; in=n-1;}
  for(int i=0; i < in; ++i)
    psi[i]=angle(v[i+1]-v[i],v[i+2]-v[i+1],camera);
  if(cyclic) {
    l.cyclic(true);
    psi.cyclic(true);
  } else {
    psi[n-1]=0;
    if(dir0 == O) {
      real a0=alpha[0];
      real b0=beta[0];
      a[0]=0;
      b[0]=g0*b0^3+a0^3*(3b0-1);
      real C=g0*b0^3*(3a0-1)+a0^3;
      c[0]=C;
      f[0]=-C*psi[0];
    } else {
      a[0]=c[0]=0;
      b[0]=1;
      f[0]=angle(v[1]-v[0],dir0,camera);
    }
    if(dirn == O) {
      real an=alpha[n-1];
      real bn=beta[n-1];
      a[n]=bn^3+gn*an^3*(3bn-1);
      real C=bn^3*(3an-1)+gn*an^3;
      b[n]=C;
      c[n]=f[n]=0;
    } else {
      a[n]=c[n]=0;
      b[n]=1;
      f[n]=angle(v[n]-v[n-1],dirn,camera);
    }
  }
  
  for(int i=i0; i < n; ++i) {
    real in=beta[i-1]^2*l[i-1];
    real A=in/alpha[i-1];
    a[i]=A;
    real B=3*in-A;
    real out=alpha[i]^2*l[i];
    real C=out/beta[i];
    b[i]=B+3*out-C;
    c[i]=C;
    f[i]=-B*psi[i-1]-C*psi[i];
  }
  
  return tridiagonal(a,b,c,f);
}

// Fill in missing directions for n cyclic nodes.
void aim(flatguide3 g, int N, triple camera) 
{
  bool cyclic=true;
  int start=0, end=0;
  
  // If the cycle contains one or more direction specifiers, break the loop.
  for(int k=0; k < N; ++k)
    if(g.solved(k)) {cyclic=false; end=k; break;}
  for(int k=N-1; k >= 0; --k)
    if(g.solved(k)) {cyclic=false; start=k; break;}
  while(start < N && g.control[start].active) ++start;
  
  int n=N-(start-end);
  if(n <= 1 || (cyclic && n <= 2)) return;

  triple[] v=new triple[cyclic ? n : n+1];
  real[] alpha=new real[n];
  real[] beta=new real[n];
  for(int k=0; k < n; ++k) {
    int K=(start+k) % N;
    v[k]=g.nodes[K];
    alpha[k]=g.Tension[K].out;
    beta[k]=g.Tension[K].in;
  }
  if(cyclic) {
    v.cyclic(true);
    alpha.cyclic(true);
    beta.cyclic(true);
  } else v[n]=g.nodes[(start+n) % N];
  int final=(end-1) % N;
  real[] theta=theta(v,alpha,beta,g.out[start].dir,g.in[final].dir,
                     g.out[start].gamma,g.in[final].gamma,camera);
  v.cyclic(true);
  theta.cyclic(true);
    
  for(int k=1; k < (cyclic ? n+1 : n); ++k) {
    triple w=dir(theta[k],v[k]-v[k-1],v[k+1]-v[k],camera);
    g.in[(start+k-1) % N].init(w);
    g.out[(start+k) % N].init(w);
  }
  if(g.out[start].dir == O)
    g.out[start].init(dir(theta[0],v[0]-g.nodes[(start-1) % N],v[1]-v[0],
                          camera));
  if(g.in[final].dir == O)
    g.in[final].init(dir(theta[n],v[n-1]-v[n-2],v[n]-v[n-1],camera));
}

// Fill in missing directions for the sequence of nodes i...n.
void aim(flatguide3 g, int i, int n, triple camera) 
{
  int j=n-i;
  if(j > 1 || g.out[i].dir != O || g.in[i].dir != O) {
    triple[] v=new triple[j+1];
    real[] alpha=new real[j];
    real[] beta=new real[j];
    for(int k=0; k < j; ++k) {
      v[k]=g.nodes[i+k];
      alpha[k]=g.Tension[i+k].out;
      beta[k]=g.Tension[i+k].in;
    }
    v[j]=g.nodes[n];
    real[] theta=theta(v,alpha,beta,g.out[i].dir,g.in[n-1].dir,
                       g.out[i].gamma,g.in[n-1].gamma,camera);
    
    for(int k=1; k < j; ++k) {
      triple w=dir(theta[k],v[k]-v[k-1],v[k+1]-v[k],camera);
      g.in[i+k-1].init(w);
      g.out[i+k].init(w);
    }
    if(g.out[i].dir == O) {
      triple w=dir(theta[0],g.in[i].dir,v[1]-v[0],camera);
      if(i > 0) g.in[i-1].init(w);
      g.out[i].init(w);
    }
    if(g.in[n-1].dir == O) {
      triple w=dir(theta[j],g.out[n-1].dir,v[j]-v[j-1],camera);
      g.in[n-1].init(w);
      g.out[n].init(w);
    }
  }
}

struct node {
  triple pre,point,post;
  bool straight;
  node copy() {
    node n=new node;
    n.pre=pre;
    n.point=point;
    n.post=post;
    n.straight=straight;
    return n;
  }
}
  
void splitCubic(node[] sn, real t, node left_, node right_)
{
  node left=sn[0]=left_.copy(), mid=sn[1], right=sn[2]=right_.copy();
  triple x=interp(left.post,right.pre,t);
  left.post=interp(left.point,left.post,t);
  right.pre=interp(right.pre,right.point,t);
  mid.pre=interp(left.post,x,t);
  mid.post=interp(x,right.pre,t);
  mid.point=interp(mid.pre,mid.post,t);
}

node[] nodes(int n)
{
  node[] nodes=new node[n];
  for(int i=0; i < n; ++i)
    nodes[i]=new node;
  return nodes;
}

struct bbox3 {
  bool empty=true;
  triple min,max;
  
  void add(triple v) {
    if(empty) {
      min=max=v;
      empty=false;
    } else {
      real x=v.x; 
      real y=v.y;
      real z=v.z;
      
      real left=min.x;
      real bottom=min.y;
      real lower=min.z;
      
      real right=max.x;
      real top=max.y;
      real upper=max.z;
      
      if(x < left)
        left = x;  
      if(x > right)
        right = x;  
      if(y < bottom)
        bottom = y;
      if(y > top)
        top = y;
      if(z < lower)
        lower = z;
      if(z > upper)
        upper = z;
      
      min=(left,bottom,lower);
      max=(right,top,upper);       
    }
  }

  void add(triple min, triple max) {
    add(min);
    add(max);
  }
  
  real diameter() {
    return length(max-min);
  }
  
  triple O() {return min;}
  triple X() {return (max.x,min.y,min.z);}
  triple XY() {return (max.x,max.y,min.z);}
  triple Y() {return (min.x,max.y,min.z);}
  triple YZ() {return (min.x,max.y,max.z);}
  triple Z() {return (min.x,min.y,max.z);}
  triple ZX() {return (max.x,min.y,max.z);}
  triple XYZ() {return max;}
}

bbox3 bbox3(triple min, triple max) 
{
  bbox3 b;
  b.add(min,max);
  return b;
}

struct path3 {
  node[] nodes;
  bool cycles;
  int n;
  real cached_length=-1;
  bbox3 box;
  
  static path3 path3(node[] nodes, bool cycles=false, real cached_length=-1) {
    path3 p=new path3;
    for(int i=0; i < nodes.length; ++i)
      p.nodes[i]=nodes[i].copy();
    p.cycles=cycles;
    p.cached_length=cached_length;
    p.n=cycles ? nodes.length-1 : nodes.length;
    return p;
  }
  
  static path3 path3(triple v) {
    node node;
    node.pre=node.point=node.post=v;
    node.straight=false;
    return path3(new node[] {node});
  }
  
  static path3 path3(node n0, node n1) {
    node N0,N1;
    N0 = n0.copy();
    N1 = n1.copy();
    N0.pre = N0.point;
    N1.post = N1.point;
    return path3(new node[] {N0,N1});
  }
  
  int size() {return n;}
  int length() {return nodes.length-1;}
  bool empty() {return n == 0;}
  bool cyclic() {return cycles;}
  
  void emptyError() {
    if(empty())
      abort("nullpath3 has no points");
  }
  
  bool straight(int i) {
    if (cycles) return nodes[i % n].straight;
    return (i >= 0 && i < n) ? nodes[i].straight : false;
  }
  
  triple point(int i) {
    emptyError();
    
    if (cycles)
      return nodes[i % n].point;
    else if (i < 0)
      return nodes[0].point;
    else if (i >= n)
      return nodes[n-1].point;
    else
      return nodes[i].point;
  }

  triple precontrol(int i) {
    emptyError();
                       
    if (cycles)
      return nodes[i % n].pre;
    else if (i < 0)
      return nodes[0].pre;
    else if (i >= n)
      return nodes[n-1].pre;
    else
      return nodes[i].pre;
  }

  triple postcontrol(int i)
  {
    emptyError();
                       
    if (cycles)
      return nodes[i % n].post;
    else if (i < 0)
      return nodes[0].post;
    else if (i >= n)
      return nodes[n-1].post;
    else
      return nodes[i].post;
  }

  triple point(real t)
  {
    emptyError();
    
    int i = Floor(t);
    int iplus;
    t = fmod(t,1);
    if (t < 0) t += 1;

    if (cycles) {
      i = i % n;
      iplus = (i+1) % n;
    }
    else if (i < 0)
      return nodes[0].point;
    else if (i >= n-1)
      return nodes[n-1].point;
    else
      iplus = i+1;

    triple a = nodes[i].point,
      b = nodes[i].post,
      c = nodes[iplus].pre,
      d = nodes[iplus].point,
      ab   = interp(a,b,t),
      bc   = interp(b,c,t),
      cd   = interp(c,d,t),
      abc  = interp(ab,bc,t),
      bcd  = interp(bc,cd,t),
      abcd = interp(abc,bcd,t);

    return abcd;
  }
  
  triple precontrol(real t) {
    emptyError();
                     
    int i = Floor(t);
    int iplus;
    t = fmod(t,1);
    if (t < 0) t += 1;

    if (cycles) {
      i = i % n;
      iplus = (i+1) % n;
    }
    else if (i < 0)
      return nodes[0].pre;
    else if (i >= n-1)
      return nodes[n-1].pre;
    else
      iplus = i+1;

    triple a = nodes[i].point,
      b = nodes[i].post,
      c = nodes[iplus].pre,
      ab   = interp(a,b,t),
      bc   = interp(b,c,t),
      abc  = interp(ab,bc,t);

    return (abc == a) ? nodes[i].pre : abc;
  }
        
 
  triple postcontrol(real t) {
    emptyError();
  
    // NOTE: may be better methods, but let's not split hairs, yet.
    int i = Floor(t);
    int iplus;
    t = fmod(t,1);
    if (t < 0) t += 1;

    if (cycles) {
      i = i % n;
      iplus = (i+1) % n;
    }
    else if (i < 0)
      return nodes[0].post;
    else if (i >= n-1)
      return nodes[n-1].post;
    else
      iplus = i+1;

    triple b = nodes[i].post,
      c = nodes[iplus].pre,
      d = nodes[iplus].point,
      bc   = interp(b,c,t),
      cd   = interp(c,d,t),
      bcd  = interp(bc,cd,t);

    return (bcd == d) ? nodes[iplus].post : bcd;
  }

  triple dir(int i)
  {
    return unit(postcontrol(i) - precontrol(i));
  }

  triple dir(real t)
  {
    return unit(postcontrol(t) - precontrol(t));
  }

  path3 concat(path3 p1, path3 p2)
  {
    int n1 = p1.length(), n2 = p2.length();

    if (n1 == -1) return p2;
    if (n2 == -1) return p1;
    triple a=p1.point(n1);
    triple b=p2.point(0);
    static real Fuzz=10*realEpsilon;
    if (abs(a-b) > Fuzz*max(abs(a),abs(b)))
      abort("path3 arguments in concatenation do not meet");

    node[] nodes = nodes(n1+n2+1);

    int i = 0;
    nodes[0].pre = p1.point(0);
    for (int j = 0; j < n1; ++j) {
      nodes[i].point = p1.point(j);
      nodes[i].straight = p1.straight(j);
      nodes[i].post = p1.postcontrol(j);
      nodes[i+1].pre = p1.precontrol(j+1);
      ++i;
    }
    for (int j = 0; j < n2; ++j) {
      nodes[i].point = p2.point(j);
      nodes[i].straight = p2.straight(j);
      nodes[i].post = p2.postcontrol(j);
      nodes[i+1].pre = p2.precontrol(j+1);
      ++i;
    }
    nodes[i].point = nodes[i].post = p2.point(n2);

    return path3(nodes);
  }

  real arclength() {
    if(cached_length != -1) return cached_length;
    
    real L=0.0;
    for(int i = 0; i < n-1; ++i)
      L += cubiclength(nodes[i].point,nodes[i].post,nodes[i+1].pre,
                       nodes[i+1].point,-1);

    if(cycles) L += cubiclength(nodes[n-1].point,nodes[n-1].post,
                                nodes[n].pre,nodes[n].point,-1);
    cached_length = L;
    return L;
  }
  
  path3 reverse() {
    node[] nodes=nodes(nodes.length);
    for(int i=0, j=length(); i < nodes.length; ++i, --j) {
      nodes[i].pre = postcontrol(j);
      nodes[i].point = point(j);
      nodes[i].post = precontrol(j);
      nodes[i].straight = straight(j-1);
    }
    return path3(nodes,cycles,cached_length);
  }
  
  real arctime(real goal) {
    if(cycles) {
      if(goal == 0) return 0;
      if(goal < 0)  {
        path3 rp = reverse();
        return -rp.arctime(-goal);
      }
      if(cached_length > 0 && goal >= cached_length) {
        int loops = (int)(goal / cached_length);
        goal -= loops*cached_length;
        return loops*n+arctime(goal);
      }      
    } else {
      if(goal <= 0)
        return 0;
      if(cached_length > 0 && goal >= cached_length)
        return n-1;
    }
    
    real l,L=0;
    for(int i = 0; i < n-1; ++i) {
      l = cubiclength(nodes[i].point,nodes[i].post,nodes[i+1].pre,
                      nodes[i+1].point,goal);
      if(l < 0)
        return (-l+i);
      else {
        L += l;
        goal -= l;
        if (goal <= 0)
          return i+1;
      }
    }
    if(cycles) {
      l = cubiclength(nodes[n-1].point,nodes[n-1].post,nodes[n].pre,
                      nodes[n].point,goal);
      if(l < 0)
        return -l+n-1;
      if(cached_length > 0 && cached_length != L+l) {
        abort("arclength != length");
      }
      cached_length = L += l;
      goal -= l;
      return arctime(goal)+n;
    }
    else {
      cached_length = L;
      return nodes.length-1;
    }
  }
  
  path3 subpath(int start, int end) {
    if(empty()) return new path3;

    if (start > end) {
      path3 rp = reverse();
      int len=length();
      path3 result = rp.subpath(len-start, len-end);
      return result;
    }

    if (!cycles) {
      if (start < 0)
        start = 0;
      if (end > n-1)
        end = n-1;
    }

    int sn = end-start+1;
    node[] nodes=nodes(sn);
    for (int i = 0, j = start; j <= end; ++i, ++j) {
      nodes[i].pre = precontrol(j);
      nodes[i].point = point(j);
      nodes[i].post = postcontrol(j);
      nodes[i].straight = straight(j);
    }
    nodes[0].pre = nodes[0].point;
    nodes[sn-1].post = nodes[sn-1].point;

    return path3(nodes);
  }
  
  path3 subpath(real start, real end)
  {
    if(empty()) return new path3;
  
    if (start > end) {
      int len=length();
      return reverse().subpath(len-start, len-end);
    }

    node startL, startR, endL, endR;
    if (!cycles) {
      if (start < 0) {
        start = 0;
        if (end < 0)
          end = 0;
      }
      if (end > n-1) {
        end = n-1;
        if (start > n-1)
          start = n-1;
      }
      startL = nodes[floor(start)];
      startR = nodes[ceil(start)];
      endL = nodes[floor(end)];
      endR = nodes[ceil(end)];
    } else {
      if(fabs(start) > intMax || fabs(end) > intMax)
        abort("invalid path index");
      startL = nodes[floor(start) % n];
      startR = nodes[ceil(start) % n];
      endL = nodes[floor(end) % n];
      endR = nodes[ceil(end) % n];
    }

    if (start == end) return path3(point(start));
    
    node[] sn=nodes(3);
    path3 p = subpath(Ceil(start), Floor(end));
    if (start > floor(start)) {
      if (end < ceil(start)) {
        splitCubic(sn,start-floor(start),startL,startR);
        splitCubic(sn,(end-start)/(ceil(end)-start),sn[1],sn[2]);
        return path3(sn[0],sn[1]);
      }
      splitCubic(sn,start-floor(start),startL,startR);
      p=concat(path3(sn[1],sn[2]),p);
    }
    if (ceil(end) > end) {
      splitCubic(sn,end-floor(end),endL,endR);
      p=concat(p,path3(sn[0],sn[1]));
    }
    return p;
  }
  
  bbox3 bounds() {
    if (empty()) {
      // No bounds
      return new bbox3;
    }

    if(!box.empty) return box;
    
    int len=length();
    for (int i = 0; i < len; ++i) {
      box.add(point(i));
      if(straight(i)) continue;
    
      triple z0=point(i);
      triple z0p=postcontrol(i);
      triple z1m=precontrol(i+1);
      triple z1=point(i+1);
      
      triple a=z1-z0+3.0*(z0p-z1m);
      triple b=2.0*(z0+z1m)-4.0*z0p;
      triple c=z0p-z0;
      
      // Check x coordinate
      real[] roots=quadraticroots(a.x,b.x,c.x);
      if(roots.length > 0) box.add(point(i+roots[0]));
      if(roots.length > 1) box.add(point(i+roots[1]));
    
      // Check y coordinate
      roots=quadraticroots(a.y,b.y,c.y);
      if(roots.length > 0) box.add(point(i+roots[0]));
      if(roots.length > 1) box.add(point(i+roots[1]));
    }
    box.add(point(length()));
    return box;
  }
  
  triple max() {
    return bounds().max;
  }
  triple min() {
    return bounds().min;
  }
  
}

bool cyclic(explicit path3 p) {return p.cyclic();}
int size(explicit path3 p) {return p.size();}
int length(explicit path3 p) {return p.length();}

path3 operator * (transform3 t, path3 p) 
{
  int m=p.nodes.length;
  node[] nodes=nodes(m);
  for(int i=0; i < m; ++i) {
    nodes[i].pre=t*p.nodes[i].pre;
    nodes[i].point=t*p.nodes[i].point;
    nodes[i].post=t*p.nodes[i].post;
  }
  return path3.path3(nodes,p.cycles);
}

void write(file file, string s="", explicit path3 x, suffix suffix=none)
{
  write(file,s);
  if(size(x) == 0) write("<nullpath3>");
  else for(int i=0; i < x.nodes.length; ++i) {
      if(i == x.nodes.length-1 && x.cycles) write(file,"cycle3");
      else write(file,x.nodes[i].point);
      if(i < length(x)) {
        if(x.nodes[i].straight) write(file,"--");
        else {
          write(file,".. controls ");
          write(file,x.nodes[i].post);
          write(file," and ");
          write(file,x.nodes[i+1].pre);
          write(file,"..",endl);
        }
      }
    }
  write(file,suffix);
}

void write(string s="", explicit path3 x, suffix suffix=endl)
{
  write(stdout,s,x,suffix);
}

path3 solve(flatguide3 g, projection Q=currentprojection)
{
  project P=aspect(Q);
  int n=g.nodes.length-1;
  path3 p;

  // If duplicate points occur consecutively, add dummy controls (if absent).
  for(int i=0; i < n; ++i) {
    if(g.nodes[i] == g.nodes[i+1] && !g.control[i].active) {
      control c;
      c.init(g.nodes[i],g.nodes[i]);
      g.control[i]=c;
    }
  }  
  
  // Fill in empty direction specifiers inherited from explicit control points.
  for(int i=0; i < n; ++i) {
    if(g.control[i].active) {
      g.out[i].default(g.control[i].post-g.nodes[i]);
      g.in[i].default(g.nodes[i+1]-g.control[i].pre);
    }
  }  
  
  // Propagate directions across nodes.
  for(int i=0; i < n; ++i) {
    int next=g.cyclic[i+1] ? 0 : i+1;
    if(g.out[next].active())
      g.in[i].default(g.out[next]);
    if(g.in[i].active()) {
      g.out[next].default(g.in[i]);
      g.out[i+1].default(g.in[i]);
    }
  }  
    
  // Compute missing 3D directions.
  // First, resolve cycles
  int i=find(g.cyclic);
  if(i > 0) {
    aim(g,i,Q.camera);
    // All other cycles can now be reduced to sequences.
    triple v=g.out[0].dir;
    for(int j=i; j <= n; ++j) {
      if(g.cyclic[j]) {
        g.in[j-1].default(v);
        g.out[j].default(v);
        if(g.nodes[j-1] == g.nodes[j] && !g.control[j-1].active) {
          control c;
          c.init(g.nodes[j-1],g.nodes[j-1]);
          g.control[j-1]=c;
        }
      }
    }
  }
    
  // Next, resolve sequences.
  int i=0;
  int start=0;
  while(i < n) {
    // Look for a missing outgoing direction.
    while(i <= n && g.solved(i)) {start=i; ++i;}
    if(i > n) break;
    // Look for the end of the sequence.
    while(i < n && !g.solved(i)) ++i;
    
    while(start < i && g.control[start].active) ++start;
    
    if(start < i) 
      aim(g,start,i,Q.camera);
  }
  
  // Compute missing 3D control points.
  for(int i=0; i < n; ++i) {
    int next=g.cyclic[i+1] ? 0 : i+1;
    if(!g.control[i].active) {
      control c;
      if((g.out[i].Curl && g.in[i].Curl) ||
         (g.out[i].dir == O && g.in[i].dir == O)) {
        // fill in straight control points for path3 functions
        triple delta=(g.nodes[i+1]-g.nodes[i])/3;
        c.init(g.nodes[i]+delta,g.nodes[i+1]-delta);
        c.active=false;
      } else {
        Controls C;
        C.init(g.nodes[i],g.nodes[next],g.out[i].dir,g.in[i].dir,
               g.Tension[i].out,g.Tension[i].in,g.Tension[i].atLeast);
        c.init(C.c0,C.c1);
      }
      g.control[i]=c;
    }
  }
  
  // Convert to Knuth's format (control points stored with nodes)
  node[] nodes=nodes(g.nodes.length);
  if(g.nodes.length == 0) return new path3;
  bool cyclic=g.cyclic[g.cyclic.length-1];
  for(int i=0; i < g.nodes.length-1; ++i) {
    nodes[i].point=g.nodes[i];
    nodes[i].post=g.control[i].post;
    nodes[i+1].pre=g.control[i].pre;
    nodes[i].straight=!g.control[i].active; // TODO: test control points here
  }
  nodes[g.nodes.length-1].point=g.nodes[g.nodes.length-1];
  if(cyclic) {
    nodes[0].pre=g.control[nodes.length-2].pre;
    nodes[g.nodes.length-1].post=g.control[nodes.length-1].post;
  } else {
    nodes[0].pre=nodes[0].point;
    nodes[g.nodes.length-1].post=nodes[g.nodes.length-1].point;
  }
  
  return path3.path3(nodes,cyclic);
}

bool cyclic(explicit flatguide3 g) {return g.cyclic[g.cyclic.length-1];}
int size(explicit flatguide3 g) {
  return cyclic(g) ? g.nodes.length-1 : g.nodes.length;
}
int length(explicit flatguide3 g) {return g.nodes.length-1;}

path project(explicit path3 p, projection Q=currentprojection)
{
  guide g;
  project P=aspect(Q);
  
  int last=p.nodes.length-1;
  if(last < 0) return g;
  
  g=P(p.nodes[0].point);
  // Construct the path.
  for(int i=0; i < (p.cycles ? last-1 : last); ++i) {
    if(p.nodes[i].straight)
      g=g--P(p.nodes[i+1].point);
    else {
      g=g..controls P(p.nodes[i].post) and P(p.nodes[i+1].pre)..
        P(p.nodes[i+1].point);
    }
  }
  
  if(p.cycles)
    g=p.nodes[last-1].straight ? g--cycle :
      g..controls P(p.nodes[last-1].post) and P(p.nodes[last].pre)..cycle;

  return g;
}

path project(flatguide3 g, projection P=currentprojection)
{
  return project(solve(g,P),P);
}

pair project(triple v, projection P=currentprojection)
{
  project P=aspect(P);
  return P(v);
}

pair[] project(triple[] v, projection P=currentprojection)
{
  int n=v.length;
  pair[] z=new pair[n];
  for(int i=0; i < n; ++i)
    z[i]=project(v[i],P);
  return z;
}

path[] project(flatguide3[] g, projection P=currentprojection)
{
  path[] p=new path[g.length];
  for(int i=0; i < g.length; ++i) 
    p[i]=project(g[i],P);
  return p;
}
  
guide3 operator cast(path3 p) {
  guide3 g;
  int last=p.nodes.length-1;
  if(last < 0) return g;
  
  int i,stop=(p.cycles ? last-1 : last);
  // Construct the path.
  g=p.nodes[0].point;
  for(i=0; i < stop; ++i) {
    if(p.nodes[i].straight) g=g--p.nodes[i+1].point;
    else g=g..controls p.nodes[i].post and p.nodes[i+1].pre..
           p.nodes[i+1].point;
  }
  
  if(p.cycles) {
    if(p.nodes[i].straight) g=g--cycle3;
    else g=g..controls p.nodes[i].post and p.nodes[i+1].pre..cycle3;
  }
  
  return g;
}

pair operator cast(triple v) {return project(v);}
pair[] operator cast(triple[] v) {return project(v);}

position operator cast(triple x) {return project(x);}

Label Label(Label L, position position, triple align, pen p=nullpen,
            filltype filltype=NoFill) 
{
  return Label(L,position,project(align),p,filltype);
}

void label(picture pic=currentpicture, Label L, pair position,
           triple align, pen p=nullpen, filltype filltype=NoFill)
{
  label(pic,L,position,project(align),p,filltype);
}

path3 operator cast(guide3 g) {return solve(g);}
path operator cast(path3 p) {return project(p);}
path operator cast(triple v) {return project(v);}
path operator cast(guide3 g) {return project(solve(g));}
path3 operator cast(triple v) {return path3.path3(v);}

path[] operator cast(path3 g) {return new path[] {(path) g};}
path[] operator cast(guide3 g) {return new path[] {(path) g};}
path[] operator cast(guide3[] g) {return project(g);}

bool straight(path3 p, int i) {return p.straight(i);}
bool straight(explicit guide3 g, int i) {return ((path3) g).straight(i);}

triple point(path3 p, int i) {return p.point(i);}
triple point(explicit guide3 g, int i) {return ((path3) g).point(i);}
triple point(path3 p, real t) {return p.point(t);}
triple point(explicit guide3 g, real t) {return ((path3) g).point(t);}

triple postcontrol(path3 p, int i) {return p.postcontrol(i);}
triple postcontrol(explicit guide3 g, int i) {
  return ((path3) g).postcontrol(i);
}
triple postcontrol(path3 p, real t) {return p.postcontrol(t);}
triple postcontrol(explicit guide3 g, real t) {
  return ((path3) g).postcontrol(t);
}

triple precontrol(path3 p, int i) {return p.precontrol(i);}
triple precontrol(explicit guide3 g, int i) {
  return ((path3) g).precontrol(i);
}
triple precontrol(path3 p, real t) {return p.precontrol(t);}
triple precontrol(explicit guide3 g, real t) {
  return ((path3) g).precontrol(t);
}

triple dir(path3 p, int n) {return p.dir(n);}
triple dir(explicit guide3 g, int n) {return ((path3) g).dir(n);}
triple dir(path3 p, real t) {return p.dir(t);}
triple dir(explicit guide3 g, real t) {return ((path3) g).dir(t);}

path3 reverse(path3 p) {return p.reverse();}
path3 reverse(explicit guide3 g) {return ((path3) g).reverse();}

real arclength(path3 p) {return p.arclength();}
real arclength(explicit guide3 g) {return ((path3) g).arclength();}

real arctime(path3 p, real l) {return p.arctime(l);}
real arctime(explicit guide3 g, real l) {return ((path3) g).arctime(l);}

triple max(path3 p) {return p.max();}
triple max(explicit guide3 g) {return ((path3) g).max();}

triple min(path3 p) {return p.min();}
triple min(explicit guide3 g) {return ((path3) g).min();}

path3 subpath(path3 p, int start, int end) {return p.subpath(start,end);}
path3 subpath(explicit guide3 g, int start, int end)
{
  return ((path3) g).subpath(start,end);
}

path3 subpath(path3 p, real start, real end) {return p.subpath(start,end);}
path3 subpath(explicit guide3 g, real start, real end) 
{
  return ((path3) g).subpath(start,end);
}

real[] intersect(path3 p1, path3 p2, real fuzz=0)
{
  int L1=p1.length();
  int L2=p2.length();
  
  node[] n1=p1.nodes;
  node[] n2=p2.nodes;
    
  triple[] pre1=new triple[L1+1];
  triple[] point1=new triple[L1+1];
  triple[] post1=new triple[L1+1];
    
  triple[] pre2=new triple[L2+1];
  triple[] point2=new triple[L2+1];
  triple[] post2=new triple[L2+1];
    
  for(int i=0; i <= L1; ++i) {
    pre1[i]=n1[i].pre;
    point1[i]=n1[i].point;
    post1[i]=n1[i].post;
  }
  for(int i=0; i <= L2; ++i) {
    pre2[i]=n2[i].pre;
    point2[i]=n2[i].point;
    post2[i]=n2[i].post;
  }
  
  static real Fuzz=10.0*realEpsilon;
  fuzz=max(fuzz,Fuzz*max(max(length(p1.max()),length(p1.min())),
                         max(length(p2.max()),length(p2.min()))));
  return intersect(pre1,point1,post1,pre2,point2,post2,fuzz);
}

real[] intersect(explicit guide3 p, explicit guide3 q, real fuzz=0)
{
  return intersect((path3) p,(path3) q,fuzz);
}

triple intersectionpoint(path3 p, path3 q, real fuzz=0)
{
  real[] t=intersect(p,q,fuzz);
  if(t.length == 0) abort("paths do not intersect");
  return point(p,t[0]);
}

triple intersectionpoint(explicit guide3 p, explicit guide3 q, real fuzz=0)
{
  return intersectionpoint((path3) p,(path3) q,fuzz);
}

path3 operator & (path3 p, path3 q) {return p.concat(p,q);}
path3 operator & (explicit guide3 p, explicit guide3 q)
{
  return ((path3) p).concat(p,q);
}

// return the point on path3 g at arclength L
triple arcpoint(path3 g, real L)
{
  return point(g,arctime(g,L));
}

// return the point on guide3 g at arclength L
triple arcpoint(explicit guide3 g, real L)
{
  return point(g,arctime(g,L));
}

// return the direction on path3 g at arclength L
triple arcdir(path3 g, real L)
{
  return dir(g,arctime(g,L));
}

// return the direction on guide3 g at arclength L
triple arcdir(explicit guide3 g, real L)
{
  return dir(g,arctime(g,L));
}

// return the time on path3 g at the given relative fraction of its arclength
real reltime(path3 g, real fraction)
{
  return arctime(g,fraction*arclength(g));
}

// return the time on guide3 g at the given relative fraction of its arclength
real reltime(explicit guide3 g, real fraction)
{
  return arctime(g,fraction*arclength(g));
}

// return the point on path3 g at the given relative fraction of its arclength
triple relpoint(path3 g, real l)
{
  return point(g,reltime(g,l));
}

// return the point on guide3 g at the given relative fraction of its arclength
triple relpoint(explicit guide3 g, real l)
{
  return point(g,reltime(g,l));
}

// return the direction of path3 g at the given relative fraction of its
// arclength
triple reldir(path3 g, real l)
{
  return dir(g,reltime(g,l));
}

// return the direction of guide3 g at the given relative fraction of its
// arclength
triple reldir(explicit guide3 g, real l)
{
  return dir(g,reltime(g,l));
}

// return a rotation that maps u to Z.
transform3 align(triple u) 
{
  return rotate(colatitude(u),cross(u,Z));
}

transform rotate(explicit triple dir)
{
  return rotate((pair) dir);
} 

void draw(frame f, guide3[] g, pen p=currentpen)
{
  draw(f,(path[]) g,p);
}

void draw(picture pic=currentpicture, guide3[] g, pen p=currentpen)
{
  draw(pic,(path[]) g,p);
}

guide3[] operator ^^ (guide3 p, guide3 q) 
{
  return new guide3[] {p,q};
}

guide3[] operator ^^ (guide3 p, guide3[] q) 
{
  return concat(new guide3[] {p},q);
}

guide3[] operator ^^ (guide3[] p, guide3 q) 
{
  return concat(p,new guide3[] {q});
}

guide3[] operator ^^ (guide3[] p, guide3[] q) 
{
  return concat(p,q);
}

triple min(explicit guide3[] g)
{
  triple ming=(infinity,infinity,infinity);
  for(int i=0; i < g.length; ++i)
    ming=minbound(ming,min(g[i]));
  return ming;
}

triple max(explicit guide3[] g)
{
  triple maxg=(-infinity,-infinity,-infinity);
  for(int i=0; i < g.length; ++i)
    maxg=maxbound(maxg,max(g[i]));
  return maxg;
}

guide3[] box(triple v1, triple v2)
{
  return
    (v1.x,v1.y,v1.z)--
    (v1.x,v1.y,v2.z)--
    (v1.x,v2.y,v2.z)--
    (v1.x,v2.y,v1.z)--
    (v1.x,v1.y,v1.z)--
    (v2.x,v1.y,v1.z)--
    (v2.x,v1.y,v2.z)--
    (v2.x,v2.y,v2.z)--
    (v2.x,v2.y,v1.z)--
    (v2.x,v1.y,v1.z)^^
    (v2.x,v2.y,v1.z)--
    (v1.x,v2.y,v1.z)^^
    (v1.x,v2.y,v2.z)--
    (v2.x,v2.y,v2.z)^^
    (v2.x,v1.y,v2.z)--
    (v1.x,v1.y,v2.z);
}

guide3[] unitcube=box((0,0,0),(1,1,1));

path3 unitcircle3=X..Y..-X..-Y..cycle3;

path3 circle(triple c, real r, triple normal=Z)
{
  path3 p=scale3(r)*unitcircle3;
  if(normal != Z) 
    p=rotate(longitude(normal,warn=false),Z)*rotate(colatitude(normal),Y)*p;
  return shift(c)*p;
}

// return an arc centered at c with radius r from c+r*dir(theta1,phi1) to
// c+r*dir(theta2,phi2) in degrees, drawing in the given direction
// relative to the normal vector cross(dir(theta1,phi1),dir(theta2,phi2)).
// The normal must be explicitly specified if c and the endpoints are colinear.
path3 arc(triple c, real r, real theta1, real phi1, real theta2, real phi2,
          triple normal=O, bool direction)
{
  if(normal == O) {
    normal=cross(dir(theta1,phi1),dir(theta2,phi2));
    if(normal == O) abort("explicit normal required for these endpoints");
  }
  transform3 T=(normal.x == 0 && normal.y == 0) ? identity(4) : align(normal); 
  triple v1=T*dir(theta1,phi1);
  triple v2=T*dir(theta2,phi2);
  real t1=intersect(unitcircle3,O--2*(v1.x,v1.y,0))[0];
  real t2=intersect(unitcircle3,O--2*(v2.x,v2.y,0))[0];
  int n=length(unitcircle3);
  if(t1 >= t2 && direction) t1 -= n;
  if(t2 >= t1 && !direction) t2 -= n;
  return shift(c)*scale3(r)*inverse(T)*subpath(unitcircle3,t1,t2);
}

// return an arc centered at c with radius r from c+r*dir(theta1,phi1) to
// c+r*dir(theta2,phi2) in degrees, drawing drawing counterclockwise
// relative to the normal vector cross(dir(theta1,phi1),dir(theta2,phi2))
// iff theta2 > theta1 or (theta2 == theta1 and phi2 >= phi1).
// The normal must be explicitly specified if c and the endpoints are colinear.
// If r < 0, draw the complementary arc of radius |r|.
path3 arc(triple c, real r, real theta1, real phi1, real theta2, real phi2,
          triple normal=O)
{
  bool pos=theta2 > theta1 || (theta2 == theta1 && phi2 >= phi1);
  if(r > 0) return arc(c,r,theta1,phi1,theta2,phi2,normal,pos ? CCW : CW);
  else return arc(c,-r,theta1,phi1,theta2,phi2,normal,pos ? CW : CCW);
}

// return an arc centered at c from triple v1 to v2 (assuming |v2-c|=|v1-c|),
// drawing in the given direction.
// The normal must be explicitly specified if c and the endpoints are colinear.
path3 arc(triple c, triple v1, triple v2, triple normal=O, bool direction=CCW)
{
  v1 -= c; v2 -= c;
  return arc(c,abs(v1),colatitude(v1),longitude(v1,warn=false),
             colatitude(v2),longitude(v2,warn=false),normal,direction);
}

real epsilon=1000*realEpsilon;

// Return a representation of the plane through point O with normal cross(u,v).
path3 plane(triple u, triple v, triple O=O)
{
  return O--O+u--O+u+v--O+v--cycle3;
}

// Return the unit normal vector to a planar path p.
triple normal(path3 p)
{
  triple normal;
  real abspoint,absnext;
  
  void check(triple n) {
    if(abs(n) > epsilon*max(abspoint,absnext)) {
      n=unit(n);
      if(normal != O && abs(normal-n) > epsilon && abs(normal+n) > epsilon)
        abort("path is not planar");
      normal=n;
    }
  }

  int L=length(p);
  triple nextpre=precontrol(p,0);
  triple nextpoint=point(p,0);
  absnext=abs(nextpoint);
  
  for(int i=0; i < L; ++i) {
    triple pre=nextpre;
    triple point=nextpoint;
    triple post=postcontrol(p,i);
    nextpre=precontrol(p,i+1);
    nextpoint=point(p,i+1);
    
    abspoint=abs(point);
    absnext=abs(nextpoint);
    
    check(cross(point-pre,post-point));
    check(cross(post-point,nextpoint-nextpre));
  }
  return normal;
}

// Adjust the aspect ratio.
void aspect(projection P=currentprojection, bbox3 b,
            real x=0, real y=0, real z=0)
{
  triple L=b.max-b.min;
  if(z != 0) {
    real s=L.z/z;
    scale(P,x == 0 ? 1 : s*x/L.x, y == 0 ? 1 : s*y/L.y,1);
  } else if (y != 0) {
    real s=L.y/y;
    scale(P,x == 0 ? 1 : s*x/L.x,1,1);
  }
  else scale(P,1,1,1);
}
  
// Routines for hidden surface removal (via binary space partition):
// Structure face is derived from picture.
struct face {
  picture pic;
  transform t;
  frame fit;
  triple normal,point;
  static face face(path3 p) {
    face f=new face;
    f.normal=normal(p);
    if(f.normal == O) abort("path is linear");
    f.point=point(p,0);
    return f;
  }
  face copy() {
    face f=new face;
    f.pic=pic.copy();
    f.t=t;
    f.normal=normal;
    f.point=point;
    add(f.fit,fit);
    return f;
  }
}

picture operator cast(face f) {return f.pic;}
face operator cast(path3 p) {return face.face(p);}
  
struct line {
  triple point;
  triple dir;
}

line intersection(face a, face b) 
{
  line L;
  L.point=intersectionpoint(a.normal,a.point,b.normal,b.point);
  L.dir=unit(cross(a.normal,b.normal));
  return L;
}

struct half {
  pair[] left,right;
  
  // Sort the points in the pair array z according to whether they lie on the
  // left or right side of the line L in the direction dir passing through P.
  // Points exactly on L are considered to be on the right side.
  // Also push any points of intersection of L with the path operator --(... z)
  // onto each of the arrays left and right. 
  static half split(pair dir, pair P ... pair[] z) {
    half h=new half;
    pair lastz;
    pair invdir=dir != 0 ? 1/dir : 0;
    bool left,last;
    for(int i=0; i < z.length; ++i) {
      left=(invdir*z[i]).y > (invdir*P).y;
      if(i > 0 && last != left) {
        pair w=extension(P,P+dir,lastz,z[i]);
        h.left.push(w);
        h.right.push(w);
      }
      if(left) h.left.push(z[i]);
      else h.right.push(z[i]);
      last=left;
      lastz=z[i];
    }
    return h;  
  }
}
  
struct splitface {
  face back,front;
}

// Return the pieces obtained by splitting face a by face cut.
splitface split(face a, face cut, projection P)
{
  splitface S;
  triple camera=P.camera;

  if(abs(a.normal-cut.normal) < epsilon ||
     abs(a.normal+cut.normal) < epsilon) {
    if(abs(dot(a.point-camera,a.normal)) > 
       abs(dot(cut.point-camera,cut.normal))) {
      S.back=a;
      S.front=null;
    } else {
      S.back=null;
      S.front=a;
    }
    return S;
  }
  
  line L=intersection(a,cut);
  pair point=a.t*project(L.point,P);
  pair dir=a.t*project(L.point+L.dir,P)-point;
  pair invdir=dir != 0 ? 1/dir : 0;
  triple apoint=L.point+cross(L.dir,a.normal);
  bool left=(invdir*(a.t*project(apoint,P))).y >= (invdir*point).y;
  real t=intersect(apoint,camera,cut.normal,cut.point);
  bool rightfront=left ^ (t <= 0 || t >= 1);
  
  face back=a, front=a.copy();
  pair max=max(a.fit);
  pair min=min(a.fit);
  half h=half.split(dir,point,max,(min.x,max.y),min,(max.x,min.y),max);
  if(h.right.length == 0) {
    if(rightfront) front=null;
    else back=null;
  } else if(h.left.length == 0) {
    if(rightfront) back=null;
    else front=null;
  }
  if(front != null)
    clip(front.fit,operator --(... rightfront ? h.right : h.left)--cycle,
         zerowinding);
  if(back != null)
    clip(back.fit,operator --(... rightfront ? h.left : h.right)--cycle,
         zerowinding);
  S.back=back;
  S.front=front;
  return S;
}

// A binary space partition
struct bsp
{
  bsp back;
  bsp front;
  face node;
  
  // Construct the bsp.
  static bsp split(face[] faces, projection P) {
    if(faces.length == 0) return null;
    bsp bsp=new bsp;
    bsp.node=faces.pop();
    face[] front,back;
    for(int i=0; i < faces.length; ++i) {
      splitface split=split(faces[i],bsp.node,P);
      if(split.front != null) front.push(split.front);
      if(split.back != null) back.push(split.back);
    }
    bsp.front=bsp.split(front,P);
    bsp.back=bsp.split(back,P);
    return bsp;
  }
  
  // Draw from back to front.
  void add(frame f) {
    if(back != null) back.add(f);
    add(f,node.fit,group=true);
    if(labels(node.fit)) layer(f); // Draw over any existing TeX layers.
    if(front != null) front.add(f);
  }
}

void add(picture pic=currentpicture, face[] faces,
         projection P=currentprojection)
{
  int n=faces.length;
  face[] Faces=new face[n];
  for(int i=0; i < n; ++i)
    Faces[i]=faces[i].copy();
  
  pic.nodes.push(new void (frame f, transform t, transform T,
                           pair m, pair M) {
                   // Fit all of the pictures so we know their exact sizes.
		   face[] faces=new face[n];
                   for(int i=0; i < n; ++i) {
		     faces[i]=Faces[i].copy();
                     face F=faces[i];
		     F.t=t*T*F.pic.T;
		     F.fit=F.pic.fit(t,T*F.pic.T,m,M);
                   }
    
                   bsp bsp=bsp.split(faces,P);
                   if(bsp != null) bsp.add(f);
                 });
    
  for(int i=0; i < n; ++i) {
    picture F=Faces[i].pic;
    pic.userBox(F.userMin,F.userMax);
    pic.append(pic.bounds.point,pic.bounds.min,pic.bounds.max,F.T,F.bounds);
  }
}
