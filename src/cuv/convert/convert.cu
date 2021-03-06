//*LB*
// Copyright (c) 2010, University of Bonn, Institute for Computer Science VI
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 
//  * Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//  * Neither the name of the University of Bonn 
//    nor the names of its contributors may be used to endorse or promote
//    products derived from this software without specific prior written
//    permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//*LE*



#include <cuv/tensor_ops/tensor_ops.cuh>
#include <cuv/basics/dia_matrix.hpp>
#include <cuv/convert/convert.hpp>

namespace cuv{

    namespace convert_impl{
        /*
         * Host Dia -> Host Dense
         */
        template<class __value_type, class __mem_layout_type, class __index_type>
            static void
            convert(      tensor<__value_type, host_memory_space, __mem_layout_type>& dst, 
                    const dia_matrix<__value_type, host_memory_space,  __index_type>& src){
                if(        dst.shape()[0] != src.shape()[0]
                        || dst.shape()[1] != src.shape()[1]
                  ){
                    tensor<__value_type,host_memory_space,  __mem_layout_type> d(src.shape());
                    dst = d;
                }
                fill(dst,0);
                const
                    tensor<int, host_memory_space>& off = src.get_offsets();
                using namespace std;
                const int rf = src.row_fact();
                for(unsigned int oi=0; oi < off.size(); oi++){
                    int o = off[oi];
                    __index_type j = 1 *max((int)0, o);
                    __index_type i = rf*max((int)0,-o);
                    for(;i<src.shape()[0] && j<src.shape()[1]; j++){
                        for(int k=0;k<rf;k++,i++)
                            dst(i,j)=src(i,j);
                    }
                }
            }

        /*
         * Host Dia -> Dev Dia
         */
        template<class __value_type, class __index_type>
            static void
            convert(      dia_matrix <__value_type, dev_memory_space, __index_type>& dst, 
                    const dia_matrix<__value_type, host_memory_space, __index_type>& src){
                if(        dst.shape()[0] != src.shape()[0]
                        || dst.shape()[1] != src.shape()[1]
                        || dst.row_fact() != src.row_fact()
                        || !dst.vec_ptr()
                  ){
                    dst.dealloc();
                    dst = dia_matrix<__value_type,dev_memory_space,__index_type>(src.shape()[0],src.shape()[1],src.num_dia(),src.stride(),src.row_fact());
                }
                cuvAssert(dst.vec_ptr())
                    cuvAssert(src.vec_ptr())
                    cuvAssert(dst.get_offsets().ptr());
                cuvAssert(dst.vec().ptr());
                cuv::convert(dst.get_offsets(), src.get_offsets());
		dst.vec() = src.vec();
                dst.post_update_offsets();
            }

        /*
         * Dev Dia -> Host Dia
         */
        template<class __value_type, class __index_type>
            static void
            convert(      dia_matrix <__value_type,host_memory_space, __index_type>& dst, 
                    const dia_matrix<__value_type,dev_memory_space, __index_type>& src){
                if(        dst.shape()[0] != src.shape()[0]
                        || dst.shape()[1] != src.shape()[1]
                        || dst.row_fact() != src.row_fact()
                        || !dst.vec_ptr()
                  ){
                    dst.dealloc();
                    dst = dia_matrix<__value_type,host_memory_space, __index_type>(src.shape()[0],src.shape()[1],src.num_dia(),src.stride(),src.row_fact());
                }
                cuvAssert(dst.get_offsets().ptr());
                cuvAssert(dst.vec().ptr());
                cuv::convert(dst.get_offsets(), src.get_offsets());
		dst.vec() = src.vec();
                dst.post_update_offsets();
            }

        /**
         * value type conversion
         */
        template<class V1,class V2,  class M, class L>
            static void
            convert(      tensor<V1, M,L>& dst, 
                    const tensor<V2, M, L>& src){
                typedef typename memspace_cuv2thrustptr<V1, M>::ptr_type ptr_type1;
                typedef typename memspace_cuv2thrustptr<V2, M>::ptr_type ptr_type2;
                ptr_type1 d_ptr(dst.ptr());
                ptr_type2 s_ptr(const_cast<V2*>(src.ptr()));
                thrust::copy(s_ptr, s_ptr+src.size(), d_ptr);
	    }

        /*
         * Everything else
         */
        template<class __value_type,  class __memory_space, class __mem_layout_type,
		 class __value_type2, class __memory_space2, class __mem_layout_type2>
            static void
            convert(      tensor<__value_type,  __memory_space,  __mem_layout_type>& dst, 
                    const tensor<__value_type2, __memory_space2, __mem_layout_type2>& src){
		    dst = src;
	    }
        template<class __value_type,  class __memory_space, class __mem_layout_type, class __index_type,
		 class __value_type2, class __memory_space2, class __mem_layout_type2, class __index_type2>
            static void
            convert(      tensor<__value_type,  __memory_space,  __mem_layout_type>& dst, 
                    const tensor<__value_type2, __memory_space2, __mem_layout_type2>& src){
		    dst = src;
	    }
    }
    template<class Dst, class Src>
        void convert(Dst& dst, const Src& src)
        {
            /*convert_impl::convert<typename Dst::value_type, typename Dst::index_type>(dst,src); // hmm the compiler should deduce template args, but it fails to do so.*/
            convert_impl::convert<typename Dst::value_type>(dst,src); // hmm the compiler should deduce template args, but it fails to do so.
        };


#define CONV_INST(X,Y,Z) \
    template void convert<tensor<X,dev_memory_space,Y>,          tensor<X,host_memory_space,Z> > \
    (                 tensor<X,dev_memory_space,Y>&,   const tensor<X,host_memory_space,Z>&); \
    template void convert<tensor<X,host_memory_space,Y>,         tensor<X,dev_memory_space,Z> > \
    (                 tensor<X,host_memory_space,Y>&,  const tensor<X,dev_memory_space,Z>&);

#define CONV_SIMPLE_INST(X,Y) \
    template void convert<tensor<X,host_memory_space,Y>,         tensor<X,host_memory_space,Y> > \
    (                 tensor<X,host_memory_space,Y>&,  const tensor<X,host_memory_space,Y>&);


    CONV_INST(float,column_major,column_major);
    /*CONV_INST(float,column_major,row_major);*/
    /*CONV_INST(float,row_major,   column_major);*/
    CONV_INST(float,row_major,   row_major);

    CONV_INST(unsigned char,column_major,column_major);
    /*CONV_INST(unsigned char,column_major,row_major);*/
    /*CONV_INST(unsigned char,row_major,   column_major);*/
    CONV_INST(unsigned char,row_major,   row_major);

    CONV_INST(signed char,column_major,column_major);
    /*CONV_INST(signed char,column_major,row_major);*/
    /*CONV_INST(signed char,row_major,   column_major);*/
    CONV_INST(signed char,row_major,   row_major);

    CONV_INST(int,column_major,column_major);
    /*CONV_INST(int,column_major,row_major);*/
    /*CONV_INST(int,row_major,   column_major);*/
    CONV_INST(int,row_major,   row_major);

    CONV_INST(unsigned int,column_major,column_major);
    /*CONV_INST(unsigned int,column_major,row_major);*/
    /*CONV_INST(unsigned int,row_major,   column_major);*/
    CONV_INST(unsigned int,row_major,   row_major);

    CONV_SIMPLE_INST(int,column_major);
    CONV_SIMPLE_INST(float,column_major);
    CONV_SIMPLE_INST(signed char,column_major);
    CONV_SIMPLE_INST(unsigned char,column_major);
    CONV_SIMPLE_INST(unsigned int,column_major);

    CONV_SIMPLE_INST(int,row_major);
    CONV_SIMPLE_INST(float,row_major);
    CONV_SIMPLE_INST(signed char,row_major);
    CONV_SIMPLE_INST(unsigned char,row_major);
    CONV_SIMPLE_INST(unsigned int,row_major);

#define CONV_VALUE_TYPE(X,Y,L) \
    template void convert<tensor<X,host_memory_space,L>,          tensor<Y,host_memory_space,L> > \
    (                 tensor<X,host_memory_space,L>&,   const tensor<Y,host_memory_space,L>&); \
    template void convert<tensor<X,dev_memory_space,L>,         tensor<Y,dev_memory_space,L> > \
    (                 tensor<X,dev_memory_space,L>&,  const tensor<Y,dev_memory_space,L>&);

CONV_VALUE_TYPE(unsigned int,float,row_major);
CONV_VALUE_TYPE(unsigned int,unsigned char,row_major);

CONV_VALUE_TYPE(int,float,row_major);
CONV_VALUE_TYPE(int,unsigned char,row_major);
CONV_VALUE_TYPE(int,signed char,row_major);
CONV_VALUE_TYPE(int,unsigned int,row_major);

CONV_VALUE_TYPE(float,int,row_major);
CONV_VALUE_TYPE(float,unsigned int,row_major);
CONV_VALUE_TYPE(float,unsigned char,row_major);
CONV_VALUE_TYPE(float,signed char,row_major);


#define DIA_DENSE_CONV(X,Y,Z) \
    template <>                           \
    void convert(tensor<X,host_memory_space,Y>& dst, const dia_matrix<X,host_memory_space,Z>& src)     \
    {                                                                                \
        typedef tensor<X,host_memory_space,Y> Dst;                                        \
        convert_impl::convert<typename Dst::value_type, typename Dst::memory_layout_type, typename Dst::size_type>(dst,src);  \
    };   
#define DIA_HOST_DEV_CONV(X,Z) \
    template <>                           \
    void convert(dia_matrix<X,dev_memory_space,Z>& dst, const dia_matrix<X,host_memory_space,Z>& src)     \
    {                                                                                \
        typedef dia_matrix<X,dev_memory_space,Z> Dst;                                        \
        convert_impl::convert<typename Dst::value_type, typename Dst::index_type>(dst,src);  \
    };                                \
    template <>                           \
    void convert(dia_matrix<X,host_memory_space,Z>& dst, const dia_matrix<X,dev_memory_space,Z>& src)     \
    {                                                                                \
        typedef dia_matrix<X,host_memory_space,Z> Dst;                                        \
        convert_impl::convert<typename Dst::value_type, typename Dst::index_type>(dst,src);  \
    };                                

    DIA_DENSE_CONV(float,column_major,unsigned int)
        DIA_DENSE_CONV(float,row_major,unsigned int)
        DIA_HOST_DEV_CONV(float,unsigned int)


} // namespace cuv


