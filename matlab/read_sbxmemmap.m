function unaligned_img = read_sbxmemmap(original_mapped_data,left_margin,i)

unaligned_img = intmax('uint16') - permute(original_mapped_data.Data.img(left_margin:end,:,i),[2 1 3]);

end